import SwiftUI

struct SectionListView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        LazyVStack(spacing: 10) {
            if store.sections.isEmpty {
                EmptyFilesView()
            } else {
                ForEach(store.sections) { section in
                    SectionCardView(section: section)
                }
            }
        }
        .padding(18)
    }
}

private struct EmptyFilesView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text(store.totalCount == 0 ? "No files found" : "No files match this view")
                .font(.headline)
            Text(store.totalCount == 0 ? "Try rescanning or opening another folder." : "Switch to All or clear filters to show the scanned files.")
                .foregroundStyle(.secondary)
            if store.totalCount > 0 {
                Button("Show All Files") {
                    store.selectedSmartView = .all
                    store.selectedKinds.removeAll()
                    store.searchText = ""
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.55))
        )
    }
}

struct SectionCardView: View {
    @EnvironmentObject private var store: ProgressStore
    var section: StudySection

    private var isExpanded: Bool {
        store.expandedSections.contains(section.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                if isExpanded {
                    store.expandedSections.remove(section.id)
                } else {
                    store.expandedSections.insert(section.id)
                }
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(section.totalCount) items • \(DisplayFormat.duration(section.totalDurationSeconds))")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(section.completedCount)/\(section.totalCount)")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: section.completionFraction)
                        .tint(.green)
                }
                .contentShape(Rectangle())
                .padding(16)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Select Section") {
                    store.selectItems(in: section)
                }
                Button("Add Item...") {
                    store.addItem(to: section)
                }
                Button("New Markdown File...") {
                    store.createMarkdownFile(in: section)
                }
                Button("Mark Section Complete") {
                    store.markSection(section, completed: true)
                }
                Button("Mark Section Incomplete") {
                    store.markSection(section, completed: false)
                }
                Divider()
                Button("Remove List...", role: .destructive) {
                    store.removeList(section)
                }
            }

            if isExpanded {
                Divider()
                VStack(spacing: 0) {
                    if section.items.isEmpty {
                        HStack {
                            Text("No items yet")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                store.addItem(to: section)
                            } label: {
                                Label("Add Item", systemImage: "plus")
                            }
                        }
                        .padding(14)
                    } else {
                        ForEach(section.items) { item in
                            FileRowView(item: item)
                            if item.id != section.items.last?.id {
                                Divider()
                                    .padding(.leading, 54)
                            }
                        }
                    }
                }
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.55))
        )
    }
}
