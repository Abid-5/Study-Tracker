import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            DetailView()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.createManualProject()
                } label: {
                    Label("New Project", systemImage: "plus.rectangle.on.folder")
                }

                Button {
                    store.presentOpenPanel()
                } label: {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }

                Button {
                    store.addList()
                } label: {
                    Label("New List", systemImage: "list.bullet.rectangle")
                }
                .disabled(store.selectedLibrary == nil)

                Button {
                    store.addItem()
                } label: {
                    Label("New Item", systemImage: "plus.square")
                }
                .disabled(store.selectedLibrary == nil)

                Button {
                    store.addTodo()
                } label: {
                    Label("New Todo", systemImage: "checklist")
                }
                .disabled(store.selectedLibrary == nil)

                Button {
                    store.createMarkdownFile()
                } label: {
                    Label("New Markdown", systemImage: "doc.badge.plus")
                }
                .disabled(store.selectedLibrary == nil)

                Button {
                    Task { await store.rescanSelectedLibrary() }
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(store.selectedLibrary == nil || store.isScanning)

                Button {
                    store.openNextUnfinished()
                } label: {
                    Label("Continue", systemImage: "play.fill")
                }
                .disabled(store.nextUnfinishedItem == nil)
            }
        }
    }
}
