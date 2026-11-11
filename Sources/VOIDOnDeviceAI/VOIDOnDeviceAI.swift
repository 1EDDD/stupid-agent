#if os(iOS) && canImport(CoreAIKit)
import CoreAIKit
import Foundation

/// Arabic-capable local chat backed by Qwen3 0.6B through Apple's Core AI runtime.
/// The first request downloads the iPhone model bundle once; later requests use its local cache.
public enum VOIDOnDeviceAI {
    @available(iOS 27.0, *)
    public static var availabilityDescription: String {
        "Qwen3 0.6B · يعمل على الجهاز · تنزيل أول مرة قرابة 456 MB"
    }

    @available(iOS 27.0, *)
    public static var isAvailable: Bool { true }

    @available(iOS 27.0, *)
    public static func generate(
        prompt: String,
        instructions: String = "You are VOID, a private on-device assistant. Reply in the user's language, including Arabic. Be clear, accurate, and concise. Never claim to access the internet or other apps."
    ) async throws -> String {
        try await Engine.shared.respond(prompt: prompt, instructions: instructions)
    }

    @available(iOS 27.0, *)
    public static func resetConversation() async {
        await Engine.shared.reset()
    }

    @available(iOS 27.0, *)
    private actor Engine {
        static let shared = Engine()
        private var chat: ChatSession?

        func respond(prompt: String, instructions: String) async throws -> String {
            let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanPrompt.isEmpty else { throw VOIDOnDeviceAIError.emptyPrompt }

            if chat == nil {
                var configuration = ChatSession.Configuration()
                configuration.systemPrompt = instructions
                configuration.temperature = 0.7
                configuration.maxResponseTokens = 512

                // ModelStore caches the Qwen3 iPhone bundle under Application Support.
                // No API key is used; internet is needed only for this first model download.
                chat = try await ChatSession(
                    catalog: "qwen3-0.6b",
                    configuration: configuration
                )
            }

            guard let chat else { throw VOIDOnDeviceAIError.modelNotReady }
            let answer = try await chat.respond(to: cleanPrompt)
            return answer.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func reset() async {
            await chat?.reset()
        }
    }
}

public enum VOIDOnDeviceAIError: Error, LocalizedError, Sendable {
    case emptyPrompt
    case modelNotReady

    public var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "اكتب سؤالك أولاً."
        case .modelNotReady:
            return "النموذج المحلي لم يصبح جاهزاً بعد. افتح VOID وحاول مرة أخرى."
        }
    }
}
#else
import Foundation

public enum VOIDOnDeviceAI {
    public static var availabilityDescription: String {
        "يتطلب iOS 27 على جهاز يدعم Core AI"
    }
    public static var isAvailable: Bool { false }

    public static func generate(
        prompt: String,
        instructions: String = "You are VOID, a private on-device assistant."
    ) async throws -> String {
        throw VOIDOnDeviceAIError.unsupported
    }
    public static func resetConversation() async {}
}

public enum VOIDOnDeviceAIError: Error, LocalizedError, Sendable {
    case unsupported
    public var errorDescription: String? {
        "يتطلب تشغيل VOID المحلي iOS 27 وجهازاً يدعم Core AI."
    }
}
#endif
