import Foundation
import PiAgent
import PiAI

/// One conversation: its transcript in pi's JSON shape.
public struct Conversation: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var messages: [AgentMessage]

    public init(id: UUID = UUID(), title: String = "New chat", createdAt: Date = Date(), updatedAt: Date = Date(), messages: [AgentMessage] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }

    /// A title from the first user message.
    public static func title(for messages: [AgentMessage]) -> String? {
        for case let .llm(.user(user)) in messages {
            let text = contentText(user.content, separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let line = text.split(separator: "\n").first.map(String.init) ?? text
            return line.count > 60 ? String(line.prefix(60)) + "…" : line
        }
        return nil
    }
}

/// What the conversation list shows, without loading transcripts.
public struct ConversationSummary: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var updatedAt: Date
}

/// Conversations as JSON files in Application Support, outside the workspace the agent can touch.
public struct ConversationStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func appDefault() -> ConversationStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ConversationStore(directory: support.appendingPathComponent("Conversations", isDirectory: true))
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private var indexURL: URL {
        directory.appendingPathComponent("index.json")
    }

    // Dates encode losslessly (seconds since 2001), so a conversation reads back exactly as saved.
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    /// Newest first.
    public func list() -> [ConversationSummary] {
        guard let data = try? Data(contentsOf: indexURL),
              let summaries = try? Self.decoder.decode([ConversationSummary].self, from: data) else { return [] }
        return summaries.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func load(_ id: UUID) throws -> Conversation {
        try Self.decoder.decode(Conversation.self, from: Data(contentsOf: url(for: id)))
    }

    public func save(_ conversation: Conversation) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.encoder.encode(conversation).write(to: url(for: conversation.id), options: .atomic)
        var summaries = list().filter { $0.id != conversation.id }
        summaries.append(ConversationSummary(id: conversation.id, title: conversation.title, updatedAt: conversation.updatedAt))
        try Self.encoder.encode(summaries).write(to: indexURL, options: .atomic)
    }

    public func delete(_ id: UUID) throws {
        try? FileManager.default.removeItem(at: url(for: id))
        let summaries = list().filter { $0.id != id }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.encoder.encode(summaries).write(to: indexURL, options: .atomic)
    }
}
