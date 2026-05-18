import AppKit
import SwiftUI

@main
struct StudyTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ProgressStore()

    var body: some Scene {
        WindowGroup("Study Tracker") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 980, minHeight: 680)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    store.load()
                }
                .onOpenURL { url in
                    store.openFolder(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openedFolderURLs)) { notification in
                    guard let urls = notification.object as? [URL] else { return }
                    urls.forEach { store.openFolder($0) }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project...") {
                    store.createManualProject()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Open Folder...") {
                    store.presentOpenPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandMenu("Tracker") {
                Button("New List...") {
                    store.addList()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(store.selectedLibrary == nil)

                Button("New Item...") {
                    store.addItem()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(store.selectedLibrary == nil)

                Button("New Todo...") {
                    store.addTodo()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(store.selectedLibrary == nil)

                Button("New Markdown File...") {
                    store.createMarkdownFile()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(store.selectedLibrary == nil)

                Divider()

                Button(store.isBatchSelecting ? "Cancel Selection" : "Select Items") {
                    store.toggleBatchSelectionMode()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(store.filteredItems.isEmpty)

                Button("Select Visible Items") {
                    store.selectVisibleItems()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(store.filteredItems.isEmpty)

                Button("Clear Selection") {
                    store.clearSelection()
                }
                .disabled(store.selectedItemIDs.isEmpty)

                Divider()

                Button("Mark Selected Complete") {
                    store.markSelectedItems(completed: true)
                }
                .disabled(store.selectedItemIDs.isEmpty)

                Button("Mark Selected Incomplete") {
                    store.markSelectedItems(completed: false)
                }
                .disabled(store.selectedItemIDs.isEmpty)

                Button("Remove Selected Items...") {
                    store.removeSelectedItems()
                }
                .disabled(store.selectedItemIDs.isEmpty)

                Divider()

                Button("Restore Removed Items") {
                    store.restoreRemovedItems()
                }
                .disabled(store.selectedLibrary == nil)

                Divider()

                Button("Rescan Folder") {
                    Task { await store.rescanSelectedLibrary() }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(store.selectedLibrary == nil)

                Button("Continue Next Unfinished") {
                    store.openNextUnfinished()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(store.nextUnfinishedItem == nil)

                Divider()

                Button("Rename Project...") {
                    store.renameSelectedProject()
                }
                .disabled(store.selectedLibrary == nil)

                Button("Remove Project...") {
                    store.removeSelectedProject()
                }
                .disabled(store.selectedLibrary == nil)

                Divider()

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

        Settings {
            SettingsView()
                .environmentObject(store)
                .frame(width: 480)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        NotificationCenter.default.post(name: .openedFolderURLs, object: urls)
    }
}

extension Notification.Name {
    static let openedFolderURLs = Notification.Name("StudyTrackerOpenedFolderURLs")
}
