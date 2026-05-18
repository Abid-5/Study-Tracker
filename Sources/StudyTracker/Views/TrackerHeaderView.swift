import SwiftUI

struct TrackerHeaderView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.selectedLibrary?.name ?? "Study Tracker")
                        .font(.largeTitle.weight(.bold))
                        .lineLimit(2)
                    Text(summaryText)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(store.completedCount) of \(store.totalCount) items")
                        .font(.headline)
                    Text("\(DisplayFormat.percent(store.completionFraction)) Complete")
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: store.completionFraction)
                .tint(.green)

            HStack(spacing: 16) {
                MetricPill(title: "Completed", value: "\(store.completedCount)")
                MetricPill(title: "Remaining", value: "\(max(store.totalCount - store.completedCount, 0))")
                if store.totalDurationSeconds > 0 {
                    MetricPill(title: "Time", value: "\(DisplayFormat.duration(store.completedDurationSeconds)) / \(DisplayFormat.duration(store.totalDurationSeconds))")
                }
                MetricPill(title: "Sections", value: "\(store.sections.count)")
            }
        }
        .padding(24)
        .background(.regularMaterial)
    }

    private var summaryText: String {
        if store.isScanning {
            return "Scanning folder contents..."
        }
        let videoCount = store.items.filter { $0.kind == .video }.count
        let pdfCount = store.items.filter { $0.kind == .pdf }.count
        return "\(store.totalCount) files • \(videoCount) videos • \(pdfCount) PDFs"
    }
}

private struct MetricPill: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
