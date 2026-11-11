#if os(iOS)
import StupidAgentCore
import SwiftUI

private struct LocalChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

struct LocalAssistantView: View {
    @State private var messages: [LocalChatMessage] = [
        LocalChatMessage(role: .assistant, text: "أنا VOID المحلي. أعمل على الجهاز نفسه، بدون مفتاح API أو اتصال بسيرفر.")
    ]
    @State private var prompt = ""
    @State private var isGenerating = false
    @State private var notice: String?

    private let instructions = """
    You are VOID, a private on-device assistant running locally on an Apple device.
    Respond in the language used by the user. Be accurate, practical, and concise.
    You do not have internet access or external tools in this local mode. Never claim to have browsed,
    accessed other apps, inspected the device, or executed an action unless the user supplied the evidence.
    """

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    Text(VOIDLocalModel.availabilityDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Circle()
                        .fill(VOIDLocalModel.isAvailable ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                HStack {
                                    if message.role == .assistant { Spacer(minLength: 32) }
                                    Text(message.text)
                                        .padding(12)
                                        .background(
                                            message.role == .user
                                                ? Color.accentColor.opacity(0.18)
                                                : Color.secondary.opacity(0.14)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    if message.role == .user { Spacer(minLength: 32) }
                                }
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                if let notice {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                }

                HStack(alignment: .bottom, spacing: 10) {
                    TextField("اكتب لـ VOID المحلي…", text: $prompt, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)
                        .disabled(isGenerating)
                    Button(action: send) {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 30))
                        }
                    }
                    .disabled(isGenerating || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("VOID Local")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func send() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }
        prompt = ""
        notice = nil
        messages.append(LocalChatMessage(role: .user, text: text))
        isGenerating = true

        let context = messages.suffix(10).map { message in
            let role = message.role == .user ? "User" : "VOID"
            return "\(role): \(message.text)"
        }.joined(separator: "\n")

        Task { @MainActor in
            do {
                let answer = try await VOIDLocalModel.generate(prompt: context, instructions: instructions)
                messages.append(LocalChatMessage(role: .assistant, text: answer))
            } catch {
                notice = error.localizedDescription
            }
            isGenerating = false
        }
    }
}
#endif
