#if os(iOS)
import AppIntents
import VOIDOnDeviceAI

/// Makes the local VOID assistant callable from Siri, Shortcuts, Spotlight, and supported system surfaces.
@available(iOS 27.0, *)
struct AskVOIDIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask VOID"
    static let description = IntentDescription("Ask the private on-device Qwen assistant. The model is downloaded once; no API key or per-request fee.")
    static let openAppWhenRun = false

    @Parameter(title: "Prompt", description: "The question or instruction for VOID.")
    var prompt: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let answer = try await VOIDOnDeviceAI.generate(prompt: prompt)
        return .result(value: answer)
    }
}

@available(iOS 27.0, *)
struct VOIDAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskVOIDIntent(),
            phrases: [
                "Ask (.applicationName)",
                "Use (.applicationName)"
            ],
            shortTitle: "Ask VOID",
            systemImageName: "sparkles"
        )
    }
}
#endif
