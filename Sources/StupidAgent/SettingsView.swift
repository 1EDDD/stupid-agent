// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import PiAI
import PiTools
import StupidAgentCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var settings = ModelSettings()
    @State private var apiKey = ""
    @State private var availableModels: [String] = []
    @State private var loadingModels = false
    @State private var modelListError: String?
    @State private var saveError: String?
    /// The form loads the saved settings once; `onAppear` runs again when the model picker pops back.
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Provider", selection: Binding(get: { settings.preset }, set: choose)) {
                        ForEach(ProviderPreset.allCases) { preset in
                            Text(preset.name).tag(preset)
                        }
                    }
                    TextField("Base URL", text: $settings.baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(settings.preset.needsAPIKey ? "API Key" : "API Key (optional)", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Server")
                } footer: {
                    if settings.preset == .ollama || settings.preset == .lmStudio {
                        Text("On a phone, replace localhost with your computer's address on the local network.")
                    } else {
                        Text("Any server that speaks the OpenAI Chat Completions API. The key is stored in the Keychain on this device.")
                    }
                }

                Section {
                    TextField("Model ID", text: $settings.modelId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !availableModels.isEmpty {
                        Picker("Available Models", selection: $settings.modelId) {
                            ForEach(availableModels, id: \.self) { id in
                                Text(id).tag(id)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                    Button(loadingModels ? "Loading Models…" : "Load Models") { loadModels() }
                        .disabled(loadingModels || settings.baseURL.isEmpty)
                    Toggle("Reasoning Model", isOn: $settings.reasoning)
                    if settings.reasoning {
                        Picker("Thinking", selection: $settings.thinkingLevel) {
                            ForEach(ThinkingLevel.allCases.filter { $0 != .off }, id: \.self) { level in
                                Text(level.rawValue.capitalized).tag(level)
                            }
                        }
                    }
                    Toggle("Accepts Images", isOn: $settings.acceptsImages)
                } header: {
                    Text("Model")
                } footer: {
                    if let modelListError {
                        Text(modelListError).foregroundStyle(.red)
                    }
                }

                Section {
                    Toggle("Ask Before Changing Files", isOn: $settings.confirmFileChanges)
                    Toggle("Access Other Apps", isOn: $settings.allowOtherApps)
                } header: {
                    Text("Workspace")
                } footer: {
                    Text("The agent works in this app's folder, which you can open in the Files app under On My iPhone → stupid agent.")
                    if settings.allowOtherApps {
                        Text("The agent can also read and write files in other apps' containers. Requires iOS 26 or later on a real device.")
                    }
                }

                Section {
                    Picker("Web Search", selection: $settings.webSearchProvider) {
                        ForEach(WebSearchProvider.allCases, id: \.self) { provider in
                            Text(provider.name).tag(provider)
                        }
                    }
                } header: {
                    Text("Tools")
                } footer: {
                    Text("The agent can search the web, read pages and run JavaScript. Searches go to the provider chosen here; neither needs an API key.")
                }

                if let saveError {
                    Section {
                        Text(saveError).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!settings.isComplete(apiKey: apiKey))
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                settings = model.settings
                apiKey = model.apiKey ?? ""
            }
        }
    }

    /// A picked provider brings its base URL; loading saved settings doesn't go through here.
    private func choose(_ preset: ProviderPreset) {
        guard preset != settings.preset else { return }
        settings.preset = preset
        settings.baseURL = preset.baseURL
        availableModels = []
    }

    private func loadModels() {
        loadingModels = true
        modelListError = nil
        let baseURL = settings.baseURL
        let key = apiKey
        Task {
            do {
                availableModels = try await fetchModelIds(baseURL: baseURL, apiKey: key)
                if availableModels.isEmpty { modelListError = "The server listed no models." }
            } catch {
                modelListError = error.localizedDescription
            }
            loadingModels = false
        }
    }

    private func save() {
        do {
            try model.save(settings: settings, apiKey: apiKey.isEmpty ? nil : apiKey)
            dismiss()
        } catch {
            saveError = "Couldn't save: \(error.localizedDescription)"
        }
    }
}

#endif
