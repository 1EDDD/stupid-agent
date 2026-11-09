import Foundation
import PiAgent
import PiAI
import PiTools
@testable import StupidAgentCore
import Testing

@Suite struct ChatEntryTests {
    @Test func groupsAResponseWithItsThinkingAndTools() {
        let call = ToolCall(id: "c1", name: "read", arguments: ["path": "notes.md"])
        let messages: [AgentMessage] = [
            .llm(.system(SystemMessage(content: "prompt", timestamp: 0))),
            .user("hi"),
            .llm(.assistant(AssistantMessage(content: [.thinking(ThinkingContent(thinking: "hmm")), .text(TextContent(text: "Looking")), .toolCall(call)], api: "x", provider: "x", model: "x", stopReason: .toolUse, timestamp: 1))),
            .llm(.toolResult(ToolResultMessage(toolCallId: "c1", toolName: "read", content: [.text(TextContent(text: "contents"))], isError: false))),
            .llm(.assistant(AssistantMessage(content: [.text(TextContent(text: "Done"))], api: "x", provider: "x", model: "x", stopReason: .stop, timestamp: 2))),
        ]
        let entries = chatEntries(messages: messages, streaming: nil, runningToolCalls: [], isRunning: false)
        #expect(entries.map(\.kind) == [.user, .agent, .agent])
        #expect(entries[1].text == "Looking")
        #expect(entries[1].thinking == ["hmm"])
        #expect(entries[1].toolCalls.first?.status == .succeeded)
        #expect(entries[1].toolCalls.first?.title == "Read notes.md")
        #expect(entries[1].toolCalls.first?.output == "contents")
        #expect(entries[2].text == "Done")
    }

    @Test func namesWhatToolCallsWorkOn() {
        #expect(toolSummary(name: "ls", arguments: ["path": "."]) == "")
        #expect(toolSummary(name: "ls", arguments: ["path": "notes"]) == "notes")
        #expect(ToolCallItem(id: "1", name: "ls", summary: "", arguments: [:], status: .succeeded).title == "List")
        #expect(toolSummary(name: "grep", arguments: ["pattern": "todo", "path": "notes"]) == "todo in notes")
    }

    @Test func marksUnfinishedToolCalls() {
        let call = ToolCall(id: "c1", name: "write", arguments: ["path": "a.txt"])
        let messages: [AgentMessage] = [.llm(.assistant(AssistantMessage(content: [.toolCall(call)], api: "x", provider: "x", model: "x", stopReason: .toolUse)))]
        #expect(chatEntries(messages: messages, streaming: nil, runningToolCalls: ["c1"], isRunning: true).first?.toolCalls.first?.status == .running)
        #expect(chatEntries(messages: messages, streaming: nil, runningToolCalls: [], isRunning: false).first?.toolCalls.first?.status == .interrupted)
    }

    @Test func showsErrorsAndQueuedMessages() {
        var failed = AssistantMessage(api: "x", provider: "x", model: "x", stopReason: .error)
        failed.errorMessage = "401 Invalid API key"
        let entries = chatEntries(messages: [.llm(.assistant(failed))], streaming: nil, runningToolCalls: [], isRunning: false, queued: [QueuedMessage(text: "next")])
        #expect(entries.map(\.kind) == [.notice, .user])
        #expect(entries[0].isError)
        #expect(entries[0].text == "401 Invalid API key")
        #expect(entries[1].isSending)
    }
}

@Suite struct StorageTests {
    @Test func savesListsAndDeletesConversations() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("conversations-\(UUID().uuidString)")
        let store = ConversationStore(directory: directory)
        var conversation = Conversation(messages: [.user("Plan my week\nwith details")])
        conversation.title = Conversation.title(for: conversation.messages) ?? "New chat"
        try store.save(conversation)
        #expect(store.list().map(\.title) == ["Plan my week"])
        #expect(try store.load(conversation.id) == conversation)
        try store.delete(conversation.id)
        #expect(store.list().isEmpty)
    }

    @Test func settingsRequireWhatTheProviderNeeds() {
        var settings = ModelSettings(preset: .openRouter, modelId: "openai/gpt-4o-mini")
        #expect(!settings.isComplete(apiKey: nil))
        #expect(settings.isComplete(apiKey: "sk"))
        settings = ModelSettings(preset: .ollama, modelId: "llama3.2")
        #expect(settings.isComplete(apiKey: nil))
        #expect(settings.model.baseURL == "http://localhost:11434/v1")
    }

    @Test func retryDropsFailedResponses() {
        let failed = AgentMessage.llm(.assistant(AssistantMessage(api: "x", provider: "x", model: "x", stopReason: .error)))
        #expect(retryTranscript([.user("a"), failed, failed]).map(\.role) == ["user"])
    }
}

/// A provider that writes a file, then answers.
private func scriptedStream(path: String) -> StreamFunction {
    let calls = Counter()
    return { model, _, _ in
        let turn = await calls.next()
        let stream = AssistantMessageEventStream()
        let message = turn == 0
            ? AssistantMessage(content: [.toolCall(ToolCall(id: "w1", name: "write", arguments: ["path": .string(path), "content": "hello"]))], api: model.api, provider: model.provider, model: model.id, stopReason: .toolUse)
            : AssistantMessage(content: [.text(TextContent(text: "Wrote it"))], api: model.api, provider: model.provider, model: model.id, stopReason: .stop)
        stream.push(.start(partial: AssistantMessage(api: model.api, provider: model.provider, model: model.id, stopReason: .pending)))
        stream.push(.done(reason: message.stopReason, message: message))
        stream.end()
        return stream
    }
}

private actor Counter {
    private var value = 0

    func next() -> Int {
        defer { value += 1 }
        return value
    }
}

@Suite(.serialized) @MainActor struct AgentSessionTests {
    func makeSession(confirm: Bool) throws -> (AgentSession, Workspace, ConversationStore) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("workspace-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let workspace = Workspace(root: root)
        let store = ConversationStore(directory: root.appendingPathComponent(".conversations"))
        let settings = ModelSettings(preset: .custom, baseURL: "https://example.test/v1", modelId: "m", confirmFileChanges: confirm)
        let session = AgentSession(conversation: Conversation(), settings: settings, apiKey: nil, workspace: workspace, store: store, streamFunction: scriptedStream(path: "out.txt"))
        return (session, workspace, store)
    }

    func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0 ..< 200 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func runsToolsAndSaves() async throws {
        let (session, workspace, store) = try makeSession(confirm: false)
        session.send("write a file")
        // Titled as soon as it's sent.
        #expect(session.conversation.title == "write a file")
        try await waitUntil { !session.isRunning && session.messages.contains { $0.assistant?.text == "Wrote it" } }
        #expect(try String(contentsOf: workspace.root.appendingPathComponent("out.txt"), encoding: .utf8) == "hello")
        #expect(store.list().first?.title == "write a file")
        #expect(session.queued.isEmpty)
        // Each message once: events are the only source of the transcript.
        #expect(session.messages.filter { $0.role != "system" }.map(\.role) == ["user", "assistant", "toolResult", "assistant"])
        let saved = try store.load(session.conversation.id)
        #expect(saved.messages == session.messages)
    }

    @Test func asksBeforeWritingAndHonorsDenial() async throws {
        let (session, workspace, _) = try makeSession(confirm: true)
        session.send("write a file")
        try await waitUntil { session.pendingFileChange != nil }
        #expect(session.pendingFileChange?.title == "Create out.txt?")
        session.resolveFileChange(allowed: false)
        try await waitUntil { !session.isRunning && session.messages.contains { $0.assistant?.text == "Wrote it" } }
        #expect(!FileManager.default.fileExists(atPath: workspace.root.appendingPathComponent("out.txt").path))
        let result = session.messages.compactMap { if case let .llm(.toolResult(result)) = $0 { result } else { nil } }.first
        #expect(result?.isError == true)
    }
}
