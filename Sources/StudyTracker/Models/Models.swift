import Foundation

struct Library: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var rootPath: String
    var bookmarkData: Data?
    var createdAt: Date
    var lastOpenedAt: Date
    var scanSettings: ScanSettings

    var isManual: Bool {
        rootPath.isEmpty
    }
}

struct ScanSettings: Codable, Hashable {
    var includeHiddenFiles: Bool = false
    var includePackages: Bool = false
    var enabledExtensions: Set<String> = []
}

struct TrackableItem: Identifiable, Codable, Hashable {
    var id: String { relativePath }
    var libraryID: UUID
    var title: String
    var relativePath: String
    var absolutePath: String
    var fileExtension: String
    var kind: FileKind
    var byteSize: Int64
    var durationSeconds: Double?
    var pageCount: Int?
    var wordCount: Int?
    var dateAdded: Date
    var modifiedAt: Date?
    var progress: ItemProgress
}

struct ItemProgress: Codable, Hashable {
    var isCompleted: Bool = false
    var isFavorite: Bool = false
    var note: String = ""
    var tags: [String] = []
    var lastOpenedAt: Date?
    var completedAt: Date?
}

struct ProjectTodo: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
}

struct AIPlanDraft: Codable, Hashable {
    var summary: String
    var warnings: [String]
    var actions: [AIActionDraft]
}

enum AIControlMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case review
    case guarded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .review: "Review"
        case .guarded: "Guarded Autonomy"
        }
    }
}

enum AIActionRisk: String, Codable, CaseIterable, Hashable {
    case viewOnly
    case update
    case destructive

    var title: String {
        switch self {
        case .viewOnly: "View"
        case .update: "Update"
        case .destructive: "Confirm"
        }
    }
}

enum AIChatRole: String, Codable, Hashable {
    case user
    case assistant
    case system
}

struct AIConversation: Codable, Hashable {
    var id: UUID = UUID()
    var libraryID: UUID
    var messages: [AIChatMessage] = []
    var updatedAt: Date = Date()
}

struct AIChatMessage: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var role: AIChatRole
    var text: String
    var createdAt: Date = Date()
    var draft: AICommandDraft?
}

struct AICommandDraft: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var assistantMessage: String
    var warnings: [String]
    var actions: [AIActionDraft]

    enum CodingKeys: String, CodingKey {
        case assistantMessage
        case warnings
        case actions
    }

    init(id: UUID = UUID(), assistantMessage: String, warnings: [String], actions: [AIActionDraft]) {
        self.id = id
        self.assistantMessage = assistantMessage
        self.warnings = warnings
        self.actions = actions
    }
}

struct AIActionResult: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var batchID: UUID
    var actionID: UUID
    var actionTitle: String
    var actionType: AIActionType
    var risk: AIActionRisk
    var message: String
    var createdAt: Date = Date()
}

struct AIActionDraft: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var actionType: AIActionType
    var title: String
    var sectionTitle: String?
    var detail: String?
    var rationale: String?
    var estimatedMinutes: Int?
    var priority: AIPriority
    var targetID: String?
    var targetPath: String?
    var value: String?
    var kind: FileKind?
    var sortOption: SortOption?
    var groupOption: GroupOption?
    var smartView: SmartView?
    var completed: Bool?
    var favorite: Bool?
    var requiresConfirmation: Bool = false
    var risk: AIActionRisk = .update

    enum CodingKeys: String, CodingKey {
        case actionType
        case title
        case sectionTitle
        case detail
        case rationale
        case estimatedMinutes
        case priority
        case targetID
        case targetPath
        case value
        case kind
        case sortOption
        case groupOption
        case smartView
        case completed
        case favorite
        case requiresConfirmation
        case risk
    }

    init(
        id: UUID = UUID(),
        actionType: AIActionType,
        title: String,
        sectionTitle: String? = nil,
        detail: String? = nil,
        rationale: String? = nil,
        estimatedMinutes: Int? = nil,
        priority: AIPriority = .medium,
        targetID: String? = nil,
        targetPath: String? = nil,
        value: String? = nil,
        kind: FileKind? = nil,
        sortOption: SortOption? = nil,
        groupOption: GroupOption? = nil,
        smartView: SmartView? = nil,
        completed: Bool? = nil,
        favorite: Bool? = nil,
        requiresConfirmation: Bool = false,
        risk: AIActionRisk? = nil
    ) {
        self.id = id
        self.actionType = actionType
        self.title = title
        self.sectionTitle = sectionTitle
        self.detail = detail
        self.rationale = rationale
        self.estimatedMinutes = estimatedMinutes
        self.priority = priority
        self.targetID = targetID
        self.targetPath = targetPath
        self.value = value
        self.kind = kind
        self.sortOption = sortOption
        self.groupOption = groupOption
        self.smartView = smartView
        self.completed = completed
        self.favorite = favorite
        self.risk = risk ?? actionType.defaultRisk
        self.requiresConfirmation = requiresConfirmation || self.risk == .destructive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let actionType = try container.decode(AIActionType.self, forKey: .actionType)
        self.init(
            actionType: actionType,
            title: try container.decode(String.self, forKey: .title),
            sectionTitle: try container.decodeIfPresent(String.self, forKey: .sectionTitle),
            detail: try container.decodeIfPresent(String.self, forKey: .detail),
            rationale: try container.decodeIfPresent(String.self, forKey: .rationale),
            estimatedMinutes: try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes),
            priority: try container.decodeIfPresent(AIPriority.self, forKey: .priority) ?? .medium,
            targetID: try container.decodeIfPresent(String.self, forKey: .targetID),
            targetPath: try container.decodeIfPresent(String.self, forKey: .targetPath),
            value: try container.decodeIfPresent(String.self, forKey: .value),
            kind: try container.decodeIfPresent(FileKind.self, forKey: .kind),
            sortOption: try container.decodeIfPresent(SortOption.self, forKey: .sortOption),
            groupOption: try container.decodeIfPresent(GroupOption.self, forKey: .groupOption),
            smartView: try container.decodeIfPresent(SmartView.self, forKey: .smartView),
            completed: try container.decodeIfPresent(Bool.self, forKey: .completed),
            favorite: try container.decodeIfPresent(Bool.self, forKey: .favorite),
            requiresConfirmation: try container.decodeIfPresent(Bool.self, forKey: .requiresConfirmation) ?? false,
            risk: try container.decodeIfPresent(AIActionRisk.self, forKey: .risk)
        )
    }
}

enum AIActionType: String, Codable, CaseIterable, Hashable {
    case createProject
    case createList
    case createItem
    case createTodo
    case renameProject
    case renameList
    case renameItem
    case editTodo
    case editItemNote
    case markComplete
    case markIncomplete
    case favorite
    case unfavorite
    case selectItems
    case filterView
    case groupView
    case sortView
    case createMarkdownNote
    case restoreRemovedItems
    case exportProgressSuggestion
    case summarizeProgress
    case recommendNextActions
    case resetProgress

    var title: String {
        switch self {
        case .createProject: "Project"
        case .createList: "List"
        case .createItem: "Item"
        case .createTodo: "Todo"
        case .renameProject: "Rename Project"
        case .renameList: "Rename List"
        case .renameItem: "Rename Item"
        case .editTodo: "Edit Todo"
        case .editItemNote: "Edit Note"
        case .markComplete: "Mark Complete"
        case .markIncomplete: "Mark Incomplete"
        case .favorite: "Favorite"
        case .unfavorite: "Unfavorite"
        case .selectItems: "Select"
        case .filterView: "Filter"
        case .groupView: "Group"
        case .sortView: "Sort"
        case .createMarkdownNote: "Markdown"
        case .restoreRemovedItems: "Restore"
        case .exportProgressSuggestion: "Export"
        case .summarizeProgress: "Summary"
        case .recommendNextActions: "Next Actions"
        case .resetProgress: "Reset"
        }
    }

    var symbolName: String {
        switch self {
        case .createProject: "folder.badge.plus"
        case .createList: "list.bullet.rectangle"
        case .createItem: "plus.square"
        case .createTodo: "checklist"
        case .renameProject: "pencil"
        case .renameList: "text.badge.checkmark"
        case .renameItem: "pencil.line"
        case .editTodo: "checklist.checked"
        case .editItemNote: "note.text"
        case .markComplete: "checkmark.circle"
        case .markIncomplete: "circle"
        case .favorite: "star"
        case .unfavorite: "star.slash"
        case .selectItems: "checklist.unchecked"
        case .filterView: "line.3.horizontal.decrease.circle"
        case .groupView: "square.grid.2x2"
        case .sortView: "arrow.up.arrow.down"
        case .createMarkdownNote: "doc.badge.plus"
        case .restoreRemovedItems: "arrow.uturn.backward"
        case .exportProgressSuggestion: "square.and.arrow.up"
        case .summarizeProgress: "text.quote"
        case .recommendNextActions: "sparkles"
        case .resetProgress: "exclamationmark.arrow.triangle.2.circlepath"
        }
    }

    var defaultRisk: AIActionRisk {
        switch self {
        case .summarizeProgress, .recommendNextActions, .exportProgressSuggestion, .selectItems, .filterView, .groupView, .sortView:
            return .viewOnly
        case .resetProgress:
            return .destructive
        default:
            return .update
        }
    }
}

enum AIPriority: String, Codable, CaseIterable, Hashable {
    case low
    case medium
    case high

    var title: String {
        rawValue.capitalized
    }
}

struct StudySection: Identifiable, Hashable {
    var id: String { path }
    var title: String
    var path: String
    var items: [TrackableItem]
    var isManual: Bool = false

    var completedCount: Int {
        items.filter(\.progress.isCompleted).count
    }

    var totalCount: Int {
        items.count
    }

    var completionFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var totalDurationSeconds: Double {
        items.compactMap(\.durationSeconds).reduce(0, +)
    }
}

enum ExternalEditor: String, Codable, CaseIterable, Identifiable {
    case systemDefault
    case visualStudioCode
    case zed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemDefault: "System Default"
        case .visualStudioCode: "VS Code"
        case .zed: "Zed"
        }
    }

    var applicationPath: String? {
        switch self {
        case .systemDefault: nil
        case .visualStudioCode: "/Applications/Visual Studio Code.app"
        case .zed: "/Applications/Zed.app"
        }
    }
}

enum FileKind: String, Codable, CaseIterable, Hashable {
    case video
    case audio
    case pdf
    case markdown
    case presentation
    case document
    case spreadsheet
    case code
    case archive
    case image
    case other

    var label: String {
        switch self {
        case .video: "Video"
        case .audio: "Audio"
        case .pdf: "PDF"
        case .markdown: "Markdown"
        case .presentation: "Slides"
        case .document: "Document"
        case .spreadsheet: "Spreadsheet"
        case .code: "Code"
        case .archive: "Archive"
        case .image: "Image"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .video: "play.rectangle"
        case .audio: "waveform"
        case .pdf: "doc.richtext"
        case .markdown: "text.alignleft"
        case .presentation: "rectangle.on.rectangle"
        case .document: "doc.text"
        case .spreadsheet: "tablecells"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .archive: "archivebox"
        case .image: "photo"
        case .other: "doc"
        }
    }
}

enum SmartView: String, Codable, CaseIterable, Identifiable, Hashable {
    case all
    case inProgress
    case completed
    case unstarted
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .inProgress: "In Progress"
        case .completed: "Completed"
        case .unstarted: "Unstarted"
        case .favorites: "Favorites"
        }
    }

    var symbolName: String {
        switch self {
        case .all: "tray.full"
        case .inProgress: "circle.lefthalf.filled"
        case .completed: "checkmark.circle"
        case .unstarted: "circle"
        case .favorites: "star"
        }
    }
}

enum SortOption: String, Codable, CaseIterable, Identifiable, Hashable {
    case folderOrder
    case fileName
    case fileType
    case duration
    case completion
    case lastOpened
    case dateAdded
    case fileSize

    var id: String { rawValue }

    var title: String {
        switch self {
        case .folderOrder: "Folder Order"
        case .fileName: "File Name"
        case .fileType: "Type"
        case .duration: "Duration"
        case .completion: "Completion"
        case .lastOpened: "Last Opened"
        case .dateAdded: "Date Added"
        case .fileSize: "File Size"
        }
    }
}

enum GroupOption: String, Codable, CaseIterable, Identifiable, Hashable {
    case folder
    case type
    case completion
    case dateAdded
    case favorite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .folder: "Folder"
        case .type: "Type"
        case .completion: "Completion"
        case .dateAdded: "Date Added"
        case .favorite: "Favorite"
        }
    }
}
