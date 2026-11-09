// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import StupidAgentCore
import StupidChatKit
import SwiftUI

/// A conversation with the agent: stupid chatkit's chat screen, with Stop while the agent works and the alert that
/// asks before a file changes.
struct AgentChatView: View {
    @Bindable var session: AgentSession

    var body: some View {
        NetworkChatView(viewModel: AdapterChatViewModel(adapter: AgentChatAdapter(session: session), accountId: "local"))
            .id(session.conversation.id)
            .toolbar {
                if session.isRunning {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Stop", systemImage: "stop.circle") { session.stop() }
                    }
                }
            }
            .alert(
                session.pendingFileChange?.title ?? "",
                isPresented: Binding(get: { session.pendingFileChange != nil }, set: { if !$0 { session.resolveFileChange(allowed: false) } })
            ) {
                Button("Don't Allow", role: .cancel) { session.resolveFileChange(allowed: false) }
                Button("Allow") { session.resolveFileChange(allowed: true) }
            } message: {
                Text(session.pendingFileChange?.message ?? "")
            }
            .alert("Couldn't Send", isPresented: Binding(get: { session.notice != nil }, set: { if !$0 { session.notice = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(session.notice ?? "")
            }
    }
}
#endif
