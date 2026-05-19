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

struct AIActionDraft: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var actionType: AIActionType
    var title: String
    var sectionTitle: String?
    var detail: String?
    var rationale: String?
    var estimatedMinutes: Int?
    var priority: AIPriority

    enum CodingKeys: String, CodingKey {
        case actionType
        case title
        case sectionTitle
        case detail
        case rationale
        case estimatedMinutes
        case priority
    }
}

enum AIActionType: String, Codable, CaseIterable, Hashable {
    case createProject
    case createList
    case createItem
    case createTodo

    var title: String {
        switch self {
        case .createProject: "Project"
        case .createList: "List"
        case .createItem: "Item"
        case .createTodo: "Todo"
        }
    }

    var symbolName: String {
        switch self {
        case .createProject: "folder.badge.plus"
        case .createList: "list.bullet.rectangle"
        case .createItem: "plus.square"
        case .createTodo: "checklist"
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

enum SmartView: String, CaseIterable, Identifiable {
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

enum SortOption: String, CaseIterable, Identifiable {
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

enum GroupOption: String, CaseIterable, Identifiable {
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
