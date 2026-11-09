import Foundation
import PiAgent
import PiAI

/// One row of a conversation as the chat shows it.
public enum ChatItem: Identifiable, Hashable, Sendable {
    case user(id: String, text: String, imageCount: Int)
    case thinking(id: String, text: String, isStreaming: Bool)
    case text(id: String, text: String, isStreaming: Bool)
    case toolCall(ToolCallItem)
    case error(id: String, text: String)

    public var id: String {
        switch self {
        case let .user(id, _, _), let .thinking(id, _, _), let .text(id, _, _), let .error(id, _): id
        case let .toolCall(item): item.id
        }
    }
}

public struct ToolCallItem: Hashable, Sendable {
    public enum Status: Hashable, Sendable {
        /// The model is still writing the arguments.
        case preparing
        case running
        case succeeded
        case failed
        /// The run ended before the tool reported a result.
        case interrupted
    }

    public var id: String
    public var name: String
    /// A one-line description, such as the path a file tool works on.
    public var summary: String
    public var arguments: JSONObject
    public var status: Status
    public var output: String?
}

/// The rows for a transcript, plus the response streaming now.
public func chatItems(messages: [AgentMessage], streaming: AssistantMessage?, runningToolCalls: Set<String>, isRunning: Bool) -> [ChatItem] {
    var results: [String: ToolResultMessage] = [:]
    for case let .llm(.toolResult(result)) in messages {
        results[result.toolCallId] = result
    }

    var items: [ChatItem] = []
    var assistantIndex = 0
    func appendAssistant(_ message: AssistantMessage, streaming: Bool) {
        let prefix = "a\(assistantIndex)-\(message.timestamp)"
        assistantIndex += 1
        for (index, block) in message.content.enumerated() {
            let id = "\(prefix)-\(index)"
            switch block {
            case let .thinking(thinking):
                let text = thinking.thinking.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { items.append(.thinking(id: id, text: text, isStreaming: streaming && index == message.content.count - 1)) }
            case let .text(text):
                let value = text.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { items.append(.text(id: id, text: value, isStreaming: streaming)) }
            case let .toolCall(call):
                let result = results[call.id]
                let status: ToolCallItem.Status = if let result {
                    result.isError ? .failed : .succeeded
                } else if streaming {
                    .preparing
                } else if runningToolCalls.contains(call.id) || isRunning {
                    .running
                } else {
                    .interrupted
                }
                items.append(.toolCall(ToolCallItem(
                    id: call.id.isEmpty ? id : call.id,
                    name: call.name,
                    summary: toolSummary(name: call.name, arguments: call.arguments),
                    arguments: call.arguments,
                    status: status,
                    output: result.map { contentText($0.content) }
                )))
            }
        }
        if let error = message.errorMessage, message.stopReason == .error {
            items.append(.error(id: "\(prefix)-error", text: error))
        } else if message.stopReason == .aborted {
            items.append(.error(id: "\(prefix)-aborted", text: "Stopped"))
        }
    }

    for (index, message) in messages.enumerated() {
        switch message {
        case let .llm(.user(user)):
            let text = contentText(user.content).trimmingCharacters(in: .whitespacesAndNewlines)
            let images = user.content.filter { if case .image = $0 { true } else { false } }.count
            items.append(.user(id: "u\(index)-\(user.timestamp)", text: text, imageCount: images))
        case let .llm(.assistant(assistant)):
            appendAssistant(assistant, streaming: false)
        default:
            break
        }
    }
    if let streaming {
        appendAssistant(streaming, streaming: true)
    }
    return items
}

/// What a tool call works on, in a few words.
public func toolSummary(name: String, arguments: JSONObject) -> String {
    switch name {
    case "read", "write", "edit": arguments["path"]?.stringValue ?? ""
    case "ls": arguments["path"]?.stringValue ?? "."
    case "find": arguments["pattern"]?.stringValue ?? ""
    case "grep": [arguments["pattern"]?.stringValue, arguments["path"]?.stringValue].compactMap(\.self).joined(separator: " in ")
    default: arguments.keys.sorted().first.flatMap { arguments[$0]?.stringValue } ?? ""
    }
}
