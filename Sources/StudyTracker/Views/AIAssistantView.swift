import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject private var store: ProgressStore

    private let suggestions = [
        "Break this course into a 4-week study plan.",
        "Create manageable todos from these files.",
        "Suggest what I should do next without overwhelming me.",
        "Turn this syllabus text into projects, lists, and tasks."
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Assistant", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                if store.hasGeminiAPIKey == false {
                    Text("Add Gemini key in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TextEditor(text: $store.aiPrompt)
                .font(.body)
                .frame(minHeight: 74)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator)
                )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            store.aiPrompt = suggestion
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            HStack {
                if let message = store.aiStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    Task { await store.generateAIPlan() }
                } label: {
                    Label(store.isGeneratingAIPlan ? "Generating" : "Generate Draft", systemImage: "sparkles")
                }
                .disabled(store.isGeneratingAIPlan || store.hasGeminiAPIKey == false)
            }

            if let draft = store.aiDraft {
                AIDraftReviewView(draft: draft)
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.55))
        )
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .onAppear {
            store.refreshGeminiKeyStatus()
        }
    }
}

private struct AIDraftReviewView: View {
    @EnvironmentObject private var store: ProgressStore
    var draft: AIPlanDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            Text(draft.summary)
                .font(.callout)
                .foregroundStyle(.secondary)

            ForEach(draft.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            LazyVStack(spacing: 8) {
                ForEach(draft.actions) { action in
                    AIActionRow(action: action)
                }
            }

            HStack {
                Text("\(store.selectedAIActionIDs.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear Draft") {
                    store.aiDraft = nil
                    store.selectedAIActionIDs.removeAll()
                }
                Button("Apply Selected") {
                    store.applySelectedAIActions()
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.selectedAIActionIDs.isEmpty)
            }
        }
    }
}

private struct AIActionRow: View {
    @EnvironmentObject private var store: ProgressStore
    var action: AIActionDraft

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                store.toggleAIActionSelection(action)
            } label: {
                Image(systemName: store.selectedAIActionIDs.contains(action.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(store.selectedAIActionIDs.contains(action.id) ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: action.actionType.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(action.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(action.actionType.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let section = action.sectionTitle, section.isEmpty == false {
                    Text(section)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let detail = action.detail, detail.isEmpty == false {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    Text(action.priority.title)
                    if let minutes = action.estimatedMinutes {
                        Text("\(minutes)m")
                    }
                    if let rationale = action.rationale, rationale.isEmpty == false {
                        Text(rationale)
                            .lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
