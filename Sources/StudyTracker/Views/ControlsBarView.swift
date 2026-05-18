import SwiftUI

struct ControlsBarView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Picker("Group", selection: $store.groupOption) {
                    ForEach(GroupOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                Picker("Sort", selection: $store.sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                Menu {
                    ForEach(FileKind.allCases, id: \.self) { kind in
                        Button {
                            if store.selectedKinds.contains(kind) {
                                store.selectedKinds.remove(kind)
                            } else {
                                store.selectedKinds.insert(kind)
                            }
                        } label: {
                            Label(kind.label, systemImage: store.selectedKinds.contains(kind) ? "checkmark" : kind.symbolName)
                        }
                    }

                    Divider()

                    Button("Clear File Type Filters") {
                        store.selectedKinds.removeAll()
                    }
                } label: {
                    Label("Types", systemImage: "line.3.horizontal.decrease.circle")
                }

                Spacer()

                Button {
                    store.toggleBatchSelectionMode()
                } label: {
                    Label(store.isBatchSelecting ? "Cancel Select" : "Select", systemImage: store.isBatchSelecting ? "xmark.circle" : "checklist")
                }
                .disabled(store.filteredItems.isEmpty)

                Button(role: .destructive) {
                    store.resetProgress()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .disabled(store.totalCount == 0)

                Button {
                    store.restoreRemovedItems()
                } label: {
                    Label("Restore Removed", systemImage: "eye")
                }
                .disabled(store.selectedLibrary == nil)
            }

            if store.isBatchSelecting || store.selectedItemIDs.isEmpty == false {
                BatchActionsBarView()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

private struct BatchActionsBarView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        HStack(spacing: 10) {
            Text("\(store.selectedItemIDs.count) selected")
                .font(.callout.weight(.semibold))
                .frame(minWidth: 90, alignment: .leading)

            Button(store.allVisibleItemsSelected ? "Clear" : "Select Visible") {
                if store.allVisibleItemsSelected {
                    store.clearSelection()
                } else {
                    store.selectVisibleItems()
                }
            }

            Divider()
                .frame(height: 18)

            Button {
                store.markSelectedItems(completed: true)
            } label: {
                Label("Complete", systemImage: "checkmark.circle")
            }
            .disabled(store.selectedItemIDs.isEmpty)

            Button {
                store.markSelectedItems(completed: false)
            } label: {
                Label("Incomplete", systemImage: "circle")
            }
            .disabled(store.selectedItemIDs.isEmpty)

            Button {
                store.favoriteSelectedItems(true)
            } label: {
                Label("Favorite", systemImage: "star")
            }
            .disabled(store.selectedItemIDs.isEmpty)

            Button {
                store.favoriteSelectedItems(false)
            } label: {
                Label("Unfavorite", systemImage: "star.slash")
            }
            .disabled(store.selectedItemIDs.isEmpty)

            Spacer()

            Button(role: .destructive) {
                store.removeSelectedItems()
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .disabled(store.selectedItemIDs.isEmpty)
        }
        .font(.callout)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
