#if os(iOS)
import AppIntents
import StupidAgentCore

/// Makes the local VOID assistant callable from Siri, Shortcuts, Spotlight, and supported system surfaces.
@available(iOS 26.0, *)
struct AskVOIDIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask VOID"
    static let description = IntentDescription("Ask the private on-device VOID assistant. No API key or network connection is required.")
    static let openAppWhenRun = false

    @Parameter(title: "Prompt", description: "The question or instruction for VOID.")
    var prompt: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let answer = try await VOIDLocalModel.generate(prompt: prompt)
        return .result(value: answer)
    }
}

@available(iOS 26.0, *)
struct VOIDAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskVOIDIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Use \(.applicationName)"
            ],
            shortTitle: "Ask VOID",
            systemImageName: "sparkles"
        )
    }
}
#endif
