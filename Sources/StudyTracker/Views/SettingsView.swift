import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ProgressStore
    @State private var geminiKey = ""

    var body: some View {
        Form {
            Section("Scanning") {
                Toggle("Include hidden files", isOn: $store.includeHiddenFiles)
                Button("Rescan Current Folder") {
                    Task { await store.rescanSelectedLibrary() }
                }
                .disabled(store.selectedLibrary == nil)
            }

            Section("Completion") {
                Toggle("Mark files complete when opened", isOn: $store.markCompleteWhenOpened)
                Text("Manual tracking stays available for every file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Markdown") {
                Picker("Open new files in", selection: $store.preferredEditor) {
                    ForEach(ExternalEditor.allCases) { editor in
                        Text(editor.title).tag(editor)
                    }
                }
                Text("If the selected editor is not installed, the app falls back to the system default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Gemini") {
                SecureField("Gemini API key", text: $geminiKey)
                HStack {
                    Button("Save Key") {
                        store.saveGeminiAPIKey(geminiKey)
                        geminiKey = ""
                    }
                    Button("Remove Key", role: .destructive) {
                        store.removeGeminiAPIKey()
                        geminiKey = ""
                    }
                    Button("Test Connection") {
                        Task { await store.testGeminiConnection() }
                    }
                    .disabled(store.hasGeminiAPIKey == false)
                }

                Picker("Model", selection: $store.geminiModel) {
                    Text("Gemini 2.5 Flash").tag("gemini-2.5-flash")
                    Text("Gemini 2.5 Flash Lite").tag("gemini-2.5-flash-lite")
                    Text("Gemini 2.0 Flash").tag("gemini-2.0-flash")
                }

                Text(store.hasGeminiAPIKey ? "Gemini API key is stored in macOS Keychain. AI can chat and draft todos only." : "Add your Gemini API key to enable AI chat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let message = store.aiStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Data") {
                Button("Export Progress JSON...") {
                    store.exportProgressJSON()
                }
                .disabled(store.selectedLibrary == nil)

                Button("Export Progress CSV...") {
                    store.exportProgressCSV()
                }
                .disabled(store.selectedLibrary == nil)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            store.refreshGeminiKeyStatus()
        }
        .onChange(of: store.markCompleteWhenOpened) { _, _ in
            store.save()
        }
        .onChange(of: store.preferredEditor) { _, _ in
            store.save()
        }
        .onChange(of: store.geminiModel) { _, _ in
            store.save()
        }
    }
}
