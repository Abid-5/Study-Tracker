import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        List(selection: $store.selectedSmartView) {
            Section("Smart Views") {
                ForEach(SmartView.allCases) { view in
                    Label(view.title, systemImage: view.symbolName)
                        .tag(view)
                }
            }

            Section("Libraries") {
                ForEach(store.libraries) { library in
                    Button {
                        store.selectLibrary(library)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(library.name)
                                    .lineLimit(1)
                                Text(DisplayFormat.relativeDay(library.lastOpenedAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .tag(library.id)
                    .contextMenu {
                        Button("Rename Project...") {
                            store.selectLibrary(library)
                            store.renameSelectedProject()
                        }
                        Button("Remove Project...", role: .destructive) {
                            store.selectLibrary(library)
                            store.removeSelectedProject()
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            DailyGoalFooter()
                .padding(12)
        }
    }
}

private struct DailyGoalFooter: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Label("\(store.todayCompletedCount)", systemImage: "checkmark.circle")
                Spacer()
                Text("\(max(store.totalCount - store.completedCount, 0)) left")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
    }
}
