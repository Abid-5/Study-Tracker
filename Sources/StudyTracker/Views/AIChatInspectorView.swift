import SwiftUI

struct AIChatInspectorView: View {
    @EnvironmentObject private var store: ProgressStore

    private let quickCommands = [
        "Plan my week",
        "What should I do next?",
        "Create todos from PDFs",
        "Organize this project",
        "Summarize progress",
        "Make this less overwhelming"
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messages
            Divider()
            composer
        }
        .background(.regularMaterial)
        .onAppear {
            store.refreshGeminiKeyStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label("AI Chat", systemImage: "sparkles")
                .font(.headline)
            Spacer()
            Text("Chat + Todos")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                store.clearAIConversation()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Clear chat")
        }
        .padding(12)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if store.selectedAIConversation?.messages.isEmpty != false {
                        emptyState
                    }

                    ForEach(store.selectedAIConversation?.messages ?? []) { message in
                        AIMessageBubble(message: message)
                            .id(message.id)
                    }

                    if store.isGeneratingAIPlan {
                        Label("Thinking", systemImage: "ellipsis")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(12)
            }
            .onChange(of: store.selectedAIConversation?.messages.count ?? 0) { _, _ in
                if let id = store.selectedAIConversation?.messages.last?.id {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.hasGeminiAPIKey ? "Ask about this project or let Gemini draft todos." : "Add your Gemini API key in Settings to enable chat.")
                .font(.callout.weight(.semibold))
            Text("AI can chat about your project and propose new todos for review. It cannot change files, views, completion, projects, or lists.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(quickCommands, id: \.self) { command in
                        Button(command) {
                            store.runAIQuickCommand(command)
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.selectedLibrary == nil || store.hasGeminiAPIKey == false || store.isGeneratingAIPlan)
                    }
                }
            }

            TextEditor(text: $store.aiChatInput)
                .font(.body)
                .frame(minHeight: 58, maxHeight: 92)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(.separator.opacity(0.8))
                )

            HStack {
                if let message = store.aiStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    Task { await store.sendAIChatMessage() }
                } label: {
                    Label("Send", systemImage: "paperplane.fill")
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .disabled(store.selectedLibrary == nil || store.hasGeminiAPIKey == false || store.aiChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isGeneratingAIPlan)
            }
        }
        .padding(12)
    }
}

private struct AIMessageBubble: View {
    var message: AIChatMessage

    var body: some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(message.text)
                .font(.callout)
                .foregroundStyle(foreground)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .background(background, in: RoundedRectangle(cornerRadius: 8))

            if let draft = message.draft {
                AICommandDraftView(draft: draft)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private var alignment: HorizontalAlignment {
        message.role == .user ? .trailing : .leading
    }

    private var frameAlignment: Alignment {
        message.role == .user ? .trailing : .leading
    }

    private var foreground: Color {
        message.role == .system ? .secondary : .primary
    }

    private var background: Material {
        message.role == .user ? .thickMaterial : .thinMaterial
    }
}

private struct AICommandDraftView: View {
    @EnvironmentObject private var store: ProgressStore
    var draft: AICommandDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(draft.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            ForEach(draft.actions) { action in
                AICommandActionCard(action: action)
            }

            if draft.actions.isEmpty == false {
                HStack {
                    Text("\(store.selectedAIActionIDs.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") {
                        store.clearAIChatDraft()
                    }
                    Button("Add Selected") {
                        store.applySelectedAIActions()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.selectedAIActionIDs.isEmpty)
                }
            }
        }
        .padding(10)
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.5))
        )
    }
}

private struct AICommandActionCard: View {
    @EnvironmentObject private var store: ProgressStore
    var action: AIActionDraft

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Button {
                store.toggleAIActionSelection(action)
            } label: {
                Image(systemName: store.selectedAIActionIDs.contains(action.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(store.selectedAIActionIDs.contains(action.id) ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: action.actionType.symbolName)
                .foregroundStyle(action.risk == .destructive ? .red : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(action.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Text(action.risk.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(action.risk == .destructive ? .red : .secondary)
                }

                Text(action.actionType.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let detail = action.detail, detail.isEmpty == false {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    Text(action.priority.title)
                    if let minutes = action.estimatedMinutes {
                        Text("\(minutes)m")
                    }
                    if let target = action.targetPath, target.isEmpty == false {
                        Text(target)
                            .lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(9)
        .background(action.risk == .destructive ? Color.red.opacity(0.08) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
