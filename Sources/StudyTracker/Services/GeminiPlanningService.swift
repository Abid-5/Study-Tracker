import Foundation

struct GeminiPlanningService {
    var apiKey: String
    var model: String

    func generatePlan(prompt: String, context: AIPlanningContext) async throws -> AIPlanDraft {
        let command = try await generateCommand(prompt: prompt, context: context)
        return AIPlanDraft(summary: command.assistantMessage, warnings: command.warnings, actions: command.actions)
    }

    func generateCommand(prompt: String, context: AIPlanningContext) async throws -> AICommandDraft {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(prompt: prompt, context: context))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiPlanningError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Gemini request failed."
            throw GeminiPlanningError.requestFailed(http.statusCode, message)
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResponse.candidates.first?.content.parts.compactMap(\.text).joined(),
              text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw GeminiPlanningError.emptyResponse
        }

        let draftData = Data(text.utf8)
        let draft = try JSONDecoder().decode(AICommandDraft.self, from: draftData)
        return validate(draft)
    }

    func testConnection() async throws {
        let context = AIPlanningContext(projectName: "Connection Test", projectSummary: "No project data.", files: [], todos: [])
        _ = try await generatePlan(prompt: "Return one low priority todo saying connection test.", context: context)
    }

    private func validate(_ draft: AICommandDraft) -> AICommandDraft {
        let actions = draft.actions
            .filter { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .filter { $0.actionType == .createTodo }
            .prefix(40)
            .map { action in
                var updated = action
                updated.risk = .update
                updated.requiresConfirmation = false
                if updated.estimatedMinutes != nil {
                    updated.estimatedMinutes = min(max(updated.estimatedMinutes ?? 0, 5), 240)
                }
                return updated
            }
        return AICommandDraft(assistantMessage: draft.assistantMessage, warnings: draft.warnings, actions: Array(actions))
    }

    private func requestBody(prompt: String, context: AIPlanningContext) -> [String: Any] {
        [
            "contents": [
                [
                    "parts": [
                        [
                            "text": """
                            You are a planning assistant inside a macOS study tracker.
                            Respond conversationally and, when useful, include 0-10 draft todo actions.
                            Keep plans small and non-overwhelming. Prefer 3-8 practical actions.
                            You are not allowed to control the app except by proposing new todos for the user to review.
                            Do not rename, remove, mark complete, favorite, filter, sort, group, create projects, create files, or edit existing tracker data.
                            The only allowed structured action is createTodo.
                            For normal chat answers, return an empty actions array.
                            If the user asks about a file type, use the file type counts and matching file list in context.
                            If matching files exist, do not say that no matching files were found.
                            Use the user's prompt and project context.

                            User prompt:
                            \(prompt)

                            Project context:
                            \(context.promptText)
                            """
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.35,
                "responseMimeType": "application/json",
                "responseJsonSchema": responseSchema
            ]
        ]
    }

    private var responseSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "assistantMessage": ["type": "string"],
                "warnings": [
                    "type": "array",
                    "items": ["type": "string"]
                ],
                "actions": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "actionType": [
                                "type": "string",
                                "enum": [AIActionType.createTodo.rawValue]
                            ],
                            "title": ["type": "string"],
                            "sectionTitle": ["type": "string"],
                            "detail": ["type": "string"],
                            "rationale": ["type": "string"],
                            "estimatedMinutes": ["type": "integer"],
                            "priority": [
                                "type": "string",
                                "enum": AIPriority.allCases.map(\.rawValue)
                            ],
                            "targetID": ["type": "string"],
                            "targetPath": ["type": "string"],
                            "value": ["type": "string"],
                            "kind": [
                                "type": "string",
                                "enum": FileKind.allCases.map(\.rawValue)
                            ],
                            "sortOption": [
                                "type": "string",
                                "enum": SortOption.allCases.map(\.rawValue)
                            ],
                            "groupOption": [
                                "type": "string",
                                "enum": GroupOption.allCases.map(\.rawValue)
                            ],
                            "smartView": [
                                "type": "string",
                                "enum": SmartView.allCases.map(\.rawValue)
                            ],
                            "completed": ["type": "boolean"],
                            "favorite": ["type": "boolean"],
                            "requiresConfirmation": ["type": "boolean"],
                            "risk": ["type": "string", "enum": [AIActionRisk.update.rawValue]]
                        ],
                        "required": ["actionType", "title", "priority", "requiresConfirmation", "risk"]
                    ]
                ]
            ],
            "required": ["assistantMessage", "warnings", "actions"]
        ]
    }
}

struct GeminiChatService {
    var apiKey: String
    var model: String

    func send(prompt: String, context: AIPlanningContext) async throws -> AICommandDraft {
        try await GeminiPlanningService(apiKey: apiKey, model: model).generateCommand(prompt: prompt, context: context)
    }
}

struct GeminiCommandService {
    var apiKey: String
    var model: String

    func draftActions(prompt: String, context: AIPlanningContext) async throws -> AICommandDraft {
        try await GeminiPlanningService(apiKey: apiKey, model: model).generateCommand(prompt: prompt, context: context)
    }
}

struct AIPlanningContext {
    var projectName: String
    var projectSummary: String
    var files: [TrackableItem]
    var todos: [ProjectTodo]

    var promptText: String {
        let fileLines = files.prefix(80).map { item in
            "- \(item.relativePath) | \(item.kind.label) | .\(item.fileExtension) | completed: \(item.progress.isCompleted)"
        }.joined(separator: "\n")
        let todoLines = todos.prefix(40).map { todo in
            "- \(todo.title) | completed: \(todo.isCompleted)"
        }.joined(separator: "\n")
        return """
        Project: \(projectName)
        Summary: \(projectSummary)
        Files:
        \(fileLines.isEmpty ? "No files." : fileLines)
        Todos:
        \(todoLines.isEmpty ? "No todos." : todoLines)
        """
    }
}

enum GeminiPlanningError: LocalizedError {
    case invalidResponse
    case emptyResponse
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Gemini returned an invalid response."
        case .emptyResponse:
            return "Gemini returned no plan."
        case .requestFailed(let code, let message):
            return "Gemini request failed with status \(code): \(message)"
        }
    }
}

private struct GeminiResponse: Decodable {
    var candidates: [Candidate]

    struct Candidate: Decodable {
        var content: Content
    }

    struct Content: Decodable {
        var parts: [Part]
    }

    struct Part: Decodable {
        var text: String?
    }
}
