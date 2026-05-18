import SwiftUI

struct FileRowView: View {
    @EnvironmentObject private var store: ProgressStore
    @State private var showingNote = false
    @State private var noteDraft = ""
    var item: TrackableItem

    var body: some View {
        HStack(spacing: 12) {
            if store.isBatchSelecting {
                Button {
                    store.toggleSelection(for: item)
                } label: {
                    Image(systemName: store.selectedItemIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(store.selectedItemIDs.contains(item.id) ? Color.accentColor : Color.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    store.toggleCompletion(for: item)
                } label: {
                    Image(systemName: item.progress.isCompleted ? "checkmark.square.fill" : "square")
                        .foregroundStyle(item.progress.isCompleted ? .green : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            Image(systemName: item.kind.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .lineLimit(1)
                Text(metadataText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if item.progress.note.isEmpty == false {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
            }

            if item.progress.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }

            Text(DisplayFormat.relativeDay(item.progress.lastOpenedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(store.selectedItemIDs.contains(item.id) ? Color.accentColor.opacity(0.12) : Color.clear)
        .onTapGesture(count: 2) {
            if store.isBatchSelecting {
                store.toggleSelection(for: item)
            } else {
                store.openItem(item)
            }
        }
        .onTapGesture {
            if store.isBatchSelecting {
                store.toggleSelection(for: item)
            }
        }
        .contextMenu {
            Button(store.selectedItemIDs.contains(item.id) ? "Deselect" : "Select") {
                store.isBatchSelecting = true
                store.toggleSelection(for: item)
            }
            if item.absolutePath.isEmpty == false {
                Button("Open") {
                    store.openItem(item)
                }
                Button("Quick Look") {
                    store.previewItem(item)
                }
            }
            Button(item.progress.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                store.toggleCompletion(for: item)
            }
            Button(item.progress.isFavorite ? "Remove Favorite" : "Favorite") {
                store.toggleFavorite(for: item)
            }
            Button("Edit Note") {
                noteDraft = item.progress.note
                showingNote = true
            }
            Divider()
            if item.absolutePath.isEmpty == false {
                Button("Reveal in Finder") {
                    store.revealItemInFinder(item)
                }
            }
            Button("Remove Item...", role: .destructive) {
                store.removeItem(item)
            }
        }
        .popover(isPresented: $showingNote) {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                TextEditor(text: $noteDraft)
                    .font(.body)
                    .frame(width: 360, height: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator)
                    )
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showingNote = false
                    }
                    Button("Save") {
                        store.updateNote(noteDraft, for: item)
                        showingNote = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
    }

    private var metadataText: String {
        var parts = [item.kind.label]
        if let duration = item.durationSeconds, duration > 0 {
            parts.append(DisplayFormat.duration(duration))
        }
        if let pageCount = item.pageCount {
            parts.append("\(pageCount) pages")
        }
        if let wordCount = item.wordCount {
            parts.append("\(wordCount) words")
        }
        parts.append(DisplayFormat.fileSize(item.byteSize))
        return parts.joined(separator: " • ")
    }
}
