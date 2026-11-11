import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device language model access shared by the VOID app, App Intents, and keyboard extension.
/// It never contacts a remote provider and does not require an API key.
public enum VOIDLocalModel {
    public static var availabilityDescription: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let model = SystemLanguageModel.default
            return model.isAvailable
                ? "Apple on-device model is ready"
                : "Apple on-device model is not ready: \(model.availability)"
        }
        #endif
        return "Requires a compatible Apple Intelligence device on iOS 26 or later"
    }

    public static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    /// Generates a response using Apple's local system model.
    /// The OS manages the model download and availability; VOID sends no prompt to a server.
    public static func generate(
        prompt: String,
        instructions: String = "You are VOID, a helpful private on-device assistant. Answer clearly and concisely."
    ) async throws -> String {
        let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { throw VOIDLocalModelError.emptyPrompt }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
                throw VOIDLocalModelError.modelUnavailable(String(describing: model.availability))
            }
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif

        throw VOIDLocalModelError.unsupported
    }
}

public enum VOIDLocalModelError: Error, LocalizedError, Sendable {
    case unsupported
    case modelUnavailable(String)
    case emptyPrompt

    public var errorDescription: String? {
        switch self {
        case .unsupported:
            return "The on-device Apple model requires a compatible device and iOS 26 or later."
        case .modelUnavailable(let reason):
            return "The on-device model is not ready. Check Apple Intelligence settings and try again. (\(reason))"
        case .emptyPrompt:
            return "Enter a prompt first."
        }
    }
}
