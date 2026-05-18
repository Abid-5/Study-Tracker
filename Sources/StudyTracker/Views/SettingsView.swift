import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ProgressStore

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
        .onChange(of: store.markCompleteWhenOpened) { _, _ in
            store.save()
        }
        .onChange(of: store.preferredEditor) { _, _ in
            store.save()
        }
    }
}
