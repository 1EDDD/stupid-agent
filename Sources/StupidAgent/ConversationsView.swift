// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import StupidAgentCore
import SwiftUI

struct ConversationsView: View {
    @Environment(AppModel.self) private var model
    @State private var path: [UUID] = []
    @State private var showSettings = false
    @State private var pendingDelete: ConversationSummary?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !model.isConfigured {
                    Section {
                        Button("Set Up a Model") { showSettings = true }
                    } footer: {
                        Text("Bring your own model: an API key from OpenAI, OpenRouter or another OpenAI-compatible server, or a model running on your computer.")
                    }
                }
                ForEach(model.conversations) { conversation in
                    NavigationLink(value: conversation.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(conversation.title)
                                .lineLimit(1)
                            Text(conversation.updatedAt, format: .relative(presentation: .named))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { pendingDelete = conversation }
                    }
                }
            }
            .overlay {
                if model.conversations.isEmpty, model.isConfigured {
                    ContentUnavailableView("No Chats", systemImage: "bubble.left.and.text.bubble.right", description: Text("Start a chat to ask the agent to work with your files."))
                }
            }
            .navigationTitle("Chats")
            .navigationDestination(for: UUID.self) { id in
                if let session = model.session(for: id) {
                    AgentChatView(session: session)
                } else {
                    ContentUnavailableView("Chat Not Found", systemImage: "exclamationmark.bubble")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gear") { showSettings = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Chat", systemImage: "square.and.pencil") {
                        path = [model.newConversation()]
                    }
                    .disabled(!model.isConfigured)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert(
                "Delete \u{201C}\(pendingDelete?.title ?? "")\u{201D}?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Chat", role: .destructive) {
                    if let id = pendingDelete?.id { model.delete(id) }
                }
            } message: {
                Text("This deletes the conversation. Files the agent made stay in your workspace.")
            }
            .onChange(of: path) { model.refresh() }
        }
    }
}

#endif
