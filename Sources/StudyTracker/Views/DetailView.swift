import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        VStack(spacing: 0) {
            if store.selectedLibrary == nil {
                EmptyStateView()
            } else {
                TrackerHeaderView()
                ControlsBarView()
                Divider()
                ScrollView {
                    TodoPanelView()
                    SectionListView()
                }
            }
        }
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search files")
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            providers.forEach { provider in
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in
                        store.openFolder(url)
                    }
                }
            }
            return true
        }
    }
}

private struct EmptyStateView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("Open a study folder")
                .font(.title2.weight(.semibold))
            Text("Nested videos, PDFs, notes, slides, and documents become a completion tracker.")
                .foregroundStyle(.secondary)
            Button {
                store.presentOpenPanel()
            } label: {
                Label("Open Folder", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
