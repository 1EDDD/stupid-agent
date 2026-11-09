// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import PiAI
import StupidAgentCore
import SwiftUI

/// A conversation with the agent. A plain SwiftUI list for now; it moves to stupid chatkit once that package exists.
struct ChatView: View {
    @Bindable var session: AgentSession
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(session.items) { item in
                        ChatItemView(item: item)
                            .id(item.id)
                    }
                    if session.isRunning, session.streamingMessage == nil, session.runningToolCalls.isEmpty {
                        ProgressView()
                            .padding(.vertical, 4)
                    }
                    if let notice = session.notice {
                        Text(notice)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if session.canRetry {
                        Button("Retry") { session.retry() }
                            .buttonStyle(.bordered)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: session.items.last) {
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
        .overlay {
            if session.items.isEmpty, !session.isRunning {
                ContentUnavailableView("Ask the Agent", systemImage: "sparkles", description: Text("It can read, write and search the files in your workspace."))
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .navigationTitle(session.conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            session.pendingFileChange?.title ?? "",
            isPresented: Binding(get: { session.pendingFileChange != nil }, set: { if !$0 { session.resolveFileChange(allowed: false) } })
        ) {
            Button("Don't Allow", role: .cancel) { session.resolveFileChange(allowed: false) }
            Button("Allow") { session.resolveFileChange(allowed: true) }
        } message: {
            Text(session.pendingFileChange?.message ?? "")
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(session.isRunning ? "Add to the task…" : "Message", text: $draft, axis: .vertical)
                .lineLimit(1 ... 6)
                .focused($composerFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.background.secondary, in: .rect(cornerRadius: 18))
            if session.isRunning, draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Stop", systemImage: "stop.circle.fill") { session.stop() }
                    .labelStyle(.iconOnly)
                    .font(.title)
            } else {
                Button("Send", systemImage: "arrow.up.circle.fill") {
                    session.send(draft)
                    draft = ""
                }
                .labelStyle(.iconOnly)
                .font(.title)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct ChatItemView: View {
    let item: ChatItem

    var body: some View {
        switch item {
        case let .user(_, text, imageCount):
            HStack {
                Spacer(minLength: 48)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(text)
                        .textSelection(.enabled)
                    if imageCount > 0 {
                        Label("\(imageCount) image\(imageCount == 1 ? "" : "s")", systemImage: "photo")
                            .font(.footnote)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: .rect(cornerRadius: 18))
            }
        case let .thinking(_, text, isStreaming):
            ThinkingView(text: text, isStreaming: isStreaming)
        case let .text(_, text, _):
            Text(markdown(text))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .toolCall(call):
            ToolCallView(call: call)
        case let .error(_, text):
            Text(text)
                .font(.footnote)
                .foregroundStyle(text == "Stopped" ? Color.secondary : Color.red)
        }
    }

    private func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

struct ThinkingView: View {
    let text: String
    let isStreaming: Bool
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(isStreaming ? "Thinking…" : "Thought")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct ToolCallView: View {
    let call: ToolCallItem
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            if let output = call.output, !output.isEmpty {
                Text(output.count > 4000 ? String(output.prefix(4000)) + "…" : output)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(JSONValue.object(call.arguments).jsonString(pretty: true))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } label: {
            HStack(spacing: 6) {
                statusIcon
                Text(verb)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
                Text(call.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var verb: String {
        switch call.name {
        case "read": "Read"
        case "write": "Write"
        case "edit": "Edit"
        case "ls": "List"
        case "find": "Find"
        case "grep": "Search"
        default: call.name
        }
    }

    @ViewBuilder private var statusIcon: some View {
        switch call.status {
        case .preparing, .running:
            ProgressView().controlSize(.mini)
        case .succeeded:
            Image(systemName: "checkmark.circle").foregroundStyle(.secondary).font(.footnote)
        case .failed:
            Image(systemName: "exclamationmark.circle").foregroundStyle(.red).font(.footnote)
        case .interrupted:
            Image(systemName: "minus.circle").foregroundStyle(.secondary).font(.footnote)
        }
    }
}

#endif
