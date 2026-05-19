import AppKit
import Combine
import Foundation

@MainActor
final class ProgressStore: ObservableObject {
    @Published var libraries: [Library] = []
    @Published var selectedLibraryID: UUID?
    @Published var selectedSmartView: SmartView = .all
    @Published var items: [TrackableItem] = []
    @Published var searchText = ""
    @Published var sortOption: SortOption = .folderOrder
    @Published var groupOption: GroupOption = .folder
    @Published var selectedKinds: Set<FileKind> = []
    @Published var includeHiddenFiles = false
    @Published var markCompleteWhenOpened = false
    @Published var preferredEditor: ExternalEditor = .systemDefault
    @Published var geminiModel = "gemini-2.5-flash"
    @Published var hasGeminiAPIKey = false
    @Published var isGeneratingAIPlan = false
    @Published var aiPrompt = ""
    @Published var aiDraft: AIPlanDraft?
    @Published var selectedAIActionIDs: Set<UUID> = []
    @Published var aiStatusMessage: String?
    @Published var isScanning = false
    @Published var expandedSections: Set<String> = []
    @Published var isBatchSelecting = false
    @Published var selectedItemIDs: Set<String> = []

    private var progressByLibraryID: [UUID: [String: ItemProgress]] = [:]
    private var manualItemsByLibraryID: [UUID: [TrackableItem]] = [:]
    private var manualListsByLibraryID: [UUID: [String]] = [:]
    private var todosByLibraryID: [UUID: [ProjectTodo]] = [:]
    private var hiddenItemPathsByLibraryID: [UUID: Set<String>] = [:]
    private var hiddenSectionPathsByLibraryID: [UUID: Set<String>] = [:]
    private let scanner = FileScanner()

    var selectedLibrary: Library? {
        get {
            guard let selectedLibraryID else { return libraries.first }
            return libraries.first { $0.id == selectedLibraryID }
        }
        set {
            selectedLibraryID = newValue?.id
        }
    }

    var filteredItems: [TrackableItem] {
        var result = items

        switch selectedSmartView {
        case .all:
            break
        case .inProgress:
            result = result.filter { !$0.progress.isCompleted }
        case .completed:
            result = result.filter(\.progress.isCompleted)
        case .unstarted:
            result = result.filter { !$0.progress.isCompleted && $0.progress.lastOpenedAt == nil }
        case .favorites:
            result = result.filter(\.progress.isFavorite)
        }

        if selectedKinds.isEmpty == false {
            result = result.filter { selectedKinds.contains($0.kind) }
        }

        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            let query = searchText.localizedLowercase
            result = result.filter {
                $0.title.localizedLowercase.contains(query)
                    || $0.relativePath.localizedLowercase.contains(query)
                    || $0.fileExtension.localizedLowercase.contains(query)
            }
        }

        return sorted(result)
    }

    var sections: [StudySection] {
        guard let libraryID = selectedLibrary?.id else { return [] }
        let grouped = Dictionary(grouping: filteredItems) { item in
            groupKey(for: item)
        }

        var resolved = grouped.map { key, sectionItems in
            StudySection(
                title: sectionTitle(for: key),
                path: key,
                items: sorted(sectionItems),
                isManual: manualListsByLibraryID[libraryID, default: []].contains(key)
            )
        }

        if groupOption == .folder {
            let existingPaths = Set(resolved.map(\.path))
            let emptyManualSections = manualListsByLibraryID[libraryID, default: []]
                .filter { existingPaths.contains($0) == false }
                .filter { hiddenSectionPathsByLibraryID[libraryID, default: []].contains($0) == false }
                .map { StudySection(title: $0, path: $0, items: [], isManual: true) }
            resolved.append(contentsOf: emptyManualSections)
        }

        return resolved
        .sorted { lhs, rhs in
            lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

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

    var completedDurationSeconds: Double {
        items.filter(\.progress.isCompleted).compactMap(\.durationSeconds).reduce(0, +)
    }

    var nextUnfinishedItem: TrackableItem? {
        sorted(items).first { !$0.progress.isCompleted }
    }

    var todayCompletedCount: Int {
        let calendar = Calendar.current
        return items.filter {
            guard let completedAt = $0.progress.completedAt else { return false }
            return calendar.isDateInToday(completedAt)
        }.count
    }

    var selectedTodos: [ProjectTodo] {
        guard let libraryID = selectedLibrary?.id else { return [] }
        return todosByLibraryID[libraryID, default: []].sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return rhs.isCompleted
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var completedTodoCount: Int {
        selectedTodos.filter(\.isCompleted).count
    }

    var selectedItems: [TrackableItem] {
        items.filter { selectedItemIDs.contains($0.id) }
    }

    var visibleItemIDs: Set<String> {
        Set(filteredItems.map(\.id))
    }

    var allVisibleItemsSelected: Bool {
        let visible = visibleItemIDs
        return visible.isEmpty == false && visible.isSubset(of: selectedItemIDs)
    }

    func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let appData = try? JSONDecoder.studyTracker.decode(AppData.self, from: data) else {
            return
        }
        libraries = appData.libraries
        progressByLibraryID = appData.progressByLibraryID
        manualItemsByLibraryID = appData.manualItemsByLibraryID
        manualListsByLibraryID = appData.manualListsByLibraryID
        todosByLibraryID = appData.todosByLibraryID
        hiddenItemPathsByLibraryID = appData.hiddenItemPathsByLibraryID
        hiddenSectionPathsByLibraryID = appData.hiddenSectionPathsByLibraryID
        selectedLibraryID = appData.selectedLibraryID ?? libraries.first?.id
        includeHiddenFiles = appData.includeHiddenFiles
        markCompleteWhenOpened = appData.markCompleteWhenOpened
        preferredEditor = appData.preferredEditor
        geminiModel = appData.geminiModel
        refreshGeminiKeyStatus()
        Task { await rescanSelectedLibrary() }
    }

    func save() {
        let appData = AppData(
            libraries: libraries,
            progressByLibraryID: progressByLibraryID,
            manualItemsByLibraryID: manualItemsByLibraryID,
            manualListsByLibraryID: manualListsByLibraryID,
            todosByLibraryID: todosByLibraryID,
            hiddenItemPathsByLibraryID: hiddenItemPathsByLibraryID,
            hiddenSectionPathsByLibraryID: hiddenSectionPathsByLibraryID,
            selectedLibraryID: selectedLibraryID,
            includeHiddenFiles: includeHiddenFiles,
            markCompleteWhenOpened: markCompleteWhenOpened,
            preferredEditor: preferredEditor,
            geminiModel: geminiModel
        )
        try? FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder.studyTracker.encode(appData) {
            try? data.write(to: storageURL, options: [.atomic])
        }
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Folder"
        if panel.runModal() == .OK, let url = panel.url {
            openFolder(url)
        }
    }

    func openFolder(_ url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        let standardized = url.standardizedFileURL
        if let existingIndex = libraries.firstIndex(where: { $0.rootPath == standardized.path }) {
            libraries[existingIndex].lastOpenedAt = Date()
            selectedLibraryID = libraries[existingIndex].id
        } else {
            let bookmark = try? standardized.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            let library = Library(
                id: UUID(),
                name: standardized.lastPathComponent,
                rootPath: standardized.path,
                bookmarkData: bookmark,
                createdAt: Date(),
                lastOpenedAt: Date(),
                scanSettings: ScanSettings(includeHiddenFiles: includeHiddenFiles)
            )
            libraries.insert(library, at: 0)
            selectedLibraryID = library.id
        }

        save()
        Task { await rescanSelectedLibrary() }
    }

    func createManualProject() {
        guard let name = requestText(title: "New Project", message: "Name this study project.", placeholder: "Project name") else {
            return
        }
        let library = Library(
            id: UUID(),
            name: name,
            rootPath: "",
            bookmarkData: nil,
            createdAt: Date(),
            lastOpenedAt: Date(),
            scanSettings: ScanSettings(includeHiddenFiles: includeHiddenFiles)
        )
        libraries.insert(library, at: 0)
        selectedLibraryID = library.id
        items = []
        save()
    }

    func renameSelectedProject() {
        guard let library = selectedLibrary,
              let name = requestText(title: "Rename Project", message: "Update the project name.", placeholder: "Project name", defaultValue: library.name),
              let index = libraries.firstIndex(where: { $0.id == library.id }) else {
            return
        }
        libraries[index].name = name
        save()
    }

    func removeSelectedProject() {
        guard let library = selectedLibrary else { return }
        let alert = NSAlert()
        alert.messageText = "Remove \(library.name)?"
        alert.informativeText = "This removes the project and its tracker data from the app. It does not delete files from disk."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        libraries.removeAll { $0.id == library.id }
        progressByLibraryID[library.id] = nil
        manualItemsByLibraryID[library.id] = nil
        manualListsByLibraryID[library.id] = nil
        todosByLibraryID[library.id] = nil
        hiddenItemPathsByLibraryID[library.id] = nil
        hiddenSectionPathsByLibraryID[library.id] = nil
        selectedLibraryID = libraries.first?.id
        items = []
        save()
        Task { await rescanSelectedLibrary() }
    }

    func selectLibrary(_ library: Library) {
        selectedLibraryID = library.id
        Task { await rescanSelectedLibrary() }
    }

    func rescanSelectedLibrary() async {
        guard var library = selectedLibrary else {
            items = []
            return
        }
        isScanning = true
        library.scanSettings.includeHiddenFiles = includeHiddenFiles
        if let index = libraries.firstIndex(where: { $0.id == library.id }) {
            libraries[index] = library
        }
        let progress = progressByLibraryID[library.id] ?? [:]
        let scanned = library.isManual ? [] : await scanner.scan(library: library, existingProgress: progress)
        let hiddenItems = hiddenItemPathsByLibraryID[library.id, default: []]
        let hiddenSections = hiddenSectionPathsByLibraryID[library.id, default: []]
        let visibleScanned = scanned.filter { item in
            hiddenItems.contains(item.relativePath) == false && hiddenSections.contains(folderPath(for: item)) == false
        }
        let visibleManual = manualItemsByLibraryID[library.id, default: []].filter { item in
            hiddenItems.contains(item.relativePath) == false && hiddenSections.contains(folderPath(for: item)) == false
        }
        items = sorted(visibleScanned + visibleManual)
        selectedItemIDs.formIntersection(Set(items.map(\.id)))
        expandedSections.formUnion(Set(sections.prefix(4).map(\.id)))
        isScanning = false
        save()
    }

    func addList() {
        guard let libraryID = selectedLibrary?.id,
              let name = requestText(title: "New List", message: "Add a list to this project.", placeholder: "List name") else {
            return
        }
        let path = uniqueSectionPath(from: name, libraryID: libraryID)
        manualListsByLibraryID[libraryID, default: []].append(path)
        hiddenSectionPathsByLibraryID[libraryID, default: []].remove(path)
        expandedSections.insert(path)
        save()
        Task { await rescanSelectedLibrary() }
    }

    func addList(named name: String) {
        guard let libraryID = selectedLibrary?.id else { return }
        let path = uniqueSectionPath(from: name, libraryID: libraryID)
        manualListsByLibraryID[libraryID, default: []].append(path)
        hiddenSectionPathsByLibraryID[libraryID, default: []].remove(path)
        expandedSections.insert(path)
        save()
        Task { await rescanSelectedLibrary() }
    }

    func removeList(_ section: StudySection) {
        guard let libraryID = selectedLibrary?.id else { return }
        let alert = NSAlert()
        alert.messageText = "Remove \(section.title)?"
        alert.informativeText = "This hides scanned files in the list and removes manually added items in it. No files are deleted from disk."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        hiddenSectionPathsByLibraryID[libraryID, default: []].insert(section.path)
        section.items.forEach { item in
            hiddenItemPathsByLibraryID[libraryID, default: []].insert(item.relativePath)
        }
        manualListsByLibraryID[libraryID, default: []].removeAll { $0 == section.path }
        manualItemsByLibraryID[libraryID, default: []].removeAll { folderPath(for: $0) == section.path }
        expandedSections.remove(section.path)
        save()
        Task { await rescanSelectedLibrary() }
    }

    func addItem(to section: StudySection? = nil) {
        guard let library = selectedLibrary,
              let title = requestText(title: "New Item", message: "Add a trackable item.", placeholder: "Item title") else {
            return
        }
        let sectionPath = section?.path ?? defaultManualSectionPath(for: library.id)
        if manualListsByLibraryID[library.id, default: []].contains(sectionPath) == false {
            manualListsByLibraryID[library.id, default: []].append(sectionPath)
        }
        let relativePath = uniqueItemPath(title: title, sectionPath: sectionPath, libraryID: library.id)
        let item = TrackableItem(
            libraryID: library.id,
            title: title,
            relativePath: relativePath,
            absolutePath: "",
            fileExtension: "",
            kind: .other,
            byteSize: 0,
            durationSeconds: nil,
            pageCount: nil,
            wordCount: nil,
            dateAdded: Date(),
            modifiedAt: nil,
            progress: ItemProgress()
        )
        manualItemsByLibraryID[library.id, default: []].append(item)
        hiddenItemPathsByLibraryID[library.id, default: []].remove(relativePath)
        expandedSections.insert(sectionPath)
        save()
        Task { await rescanSelectedLibrary() }
    }

    func addItem(title: String, sectionPath: String?) {
        guard let library = selectedLibrary else { return }
        let resolvedSectionPath = sectionPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? sectionPath!.trimmingCharacters(in: .whitespacesAndNewlines)
            : defaultManualSectionPath(for: library.id)
        if manualListsByLibraryID[library.id, default: []].contains(resolvedSectionPath) == false {
            manualListsByLibraryID[library.id, default: []].append(resolvedSectionPath)
        }
        let relativePath = uniqueItemPath(title: title, sectionPath: resolvedSectionPath, libraryID: library.id)
        let item = TrackableItem(
            libraryID: library.id,
            title: title,
            relativePath: relativePath,
            absolutePath: "",
            fileExtension: "",
            kind: .other,
            byteSize: 0,
            durationSeconds: nil,
            pageCount: nil,
            wordCount: nil,
            dateAdded: Date(),
            modifiedAt: nil,
            progress: ItemProgress(note: aiNote(sectionPath: resolvedSectionPath))
        )
        manualItemsByLibraryID[library.id, default: []].append(item)
        hiddenItemPathsByLibraryID[library.id, default: []].remove(relativePath)
        expandedSections.insert(resolvedSectionPath)
        save()
        Task { await rescanSelectedLibrary() }
    }

    func createMarkdownFile(in section: StudySection? = nil) {
        guard let library = selectedLibrary,
              let title = requestText(title: "New Markdown File", message: "Create a markdown note and open it in your preferred editor.", placeholder: "File title") else {
            return
        }

        do {
            let fileURL = try markdownFileURL(for: library, section: section, title: title)
            let template = "# \(title)\n\n"
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try template.write(to: fileURL, atomically: true, encoding: .utf8)

            if library.isManual {
                addManualMarkdownItem(title: title, fileURL: fileURL, section: section)
            }

            openInPreferredEditor(fileURL)
            save()
            Task { await rescanSelectedLibrary() }
        } catch {
            showError(title: "Could Not Create Markdown File", message: error.localizedDescription)
        }
    }

    func removeItem(_ item: TrackableItem) {
        guard let libraryID = selectedLibrary?.id else { return }
        hiddenItemPathsByLibraryID[libraryID, default: []].insert(item.relativePath)
        manualItemsByLibraryID[libraryID, default: []].removeAll { $0.relativePath == item.relativePath }
        progressByLibraryID[libraryID, default: [:]][item.relativePath] = nil
        items.removeAll { $0.relativePath == item.relativePath }
        save()
    }

    func toggleBatchSelectionMode() {
        isBatchSelecting.toggle()
        if isBatchSelecting == false {
            selectedItemIDs.removeAll()
        }
    }

    func toggleSelection(for item: TrackableItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    func selectVisibleItems() {
        selectedItemIDs.formUnion(visibleItemIDs)
        isBatchSelecting = selectedItemIDs.isEmpty == false
    }

    func selectItems(in section: StudySection) {
        selectedItemIDs.formUnion(section.items.map(\.id))
        isBatchSelecting = selectedItemIDs.isEmpty == false
    }

    func clearSelection() {
        selectedItemIDs.removeAll()
        isBatchSelecting = false
    }

    func markSelectedItems(completed: Bool) {
        selectedItems.forEach { item in
            updateProgress(for: item) { progress in
                progress.isCompleted = completed
                progress.completedAt = completed ? Date() : nil
            }
        }
    }

    func favoriteSelectedItems(_ favorite: Bool) {
        selectedItems.forEach { item in
            updateProgress(for: item) { progress in
                progress.isFavorite = favorite
            }
        }
    }

    func removeSelectedItems() {
        let selected = selectedItems
        guard selected.isEmpty == false, let libraryID = selectedLibrary?.id else { return }
        let alert = NSAlert()
        alert.messageText = "Remove \(selected.count) selected items?"
        alert.informativeText = "This removes them from the tracker. Files on disk are not deleted."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        selected.forEach { item in
            hiddenItemPathsByLibraryID[libraryID, default: []].insert(item.relativePath)
            progressByLibraryID[libraryID, default: [:]][item.relativePath] = nil
        }
        let selectedPaths = Set(selected.map(\.relativePath))
        manualItemsByLibraryID[libraryID, default: []].removeAll { selectedPaths.contains($0.relativePath) }
        items.removeAll { selectedPaths.contains($0.relativePath) }
        selectedItemIDs.removeAll()
        isBatchSelecting = false
        save()
    }

    func restoreRemovedItems() {
        guard let libraryID = selectedLibrary?.id else { return }
        hiddenItemPathsByLibraryID[libraryID] = []
        hiddenSectionPathsByLibraryID[libraryID] = []
        save()
        Task { await rescanSelectedLibrary() }
    }

    func addTodo() {
        guard let libraryID = selectedLibrary?.id,
              let title = requestText(title: "New Todo", message: "Add a project todo.", placeholder: "Todo title") else {
            return
        }
        todosByLibraryID[libraryID, default: []].append(
            ProjectTodo(id: UUID(), title: title, isCompleted: false, createdAt: Date(), completedAt: nil)
        )
        save()
    }

    func addTodo(title: String, detail: String? = nil) {
        guard let libraryID = selectedLibrary?.id else { return }
        let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard resolvedTitle.isEmpty == false else { return }
        let finalTitle: String
        if let detail, detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            finalTitle = "\(resolvedTitle) - \(detail.trimmingCharacters(in: .whitespacesAndNewlines))"
        } else {
            finalTitle = resolvedTitle
        }
        todosByLibraryID[libraryID, default: []].append(
            ProjectTodo(id: UUID(), title: finalTitle, isCompleted: false, createdAt: Date(), completedAt: nil)
        )
        save()
    }

    func toggleTodo(_ todo: ProjectTodo) {
        guard let libraryID = selectedLibrary?.id else { return }
        todosByLibraryID[libraryID] = todosByLibraryID[libraryID, default: []].map { existing in
            guard existing.id == todo.id else { return existing }
            var updated = existing
            updated.isCompleted.toggle()
            updated.completedAt = updated.isCompleted ? Date() : nil
            return updated
        }
        save()
    }

    func removeTodo(_ todo: ProjectTodo) {
        guard let libraryID = selectedLibrary?.id else { return }
        todosByLibraryID[libraryID, default: []].removeAll { $0.id == todo.id }
        save()
    }

    func toggleCompletion(for item: TrackableItem) {
        updateProgress(for: item) { progress in
            progress.isCompleted.toggle()
            progress.completedAt = progress.isCompleted ? Date() : nil
        }
    }

    func toggleFavorite(for item: TrackableItem) {
        updateProgress(for: item) { progress in
            progress.isFavorite.toggle()
        }
    }

    func updateNote(_ note: String, for item: TrackableItem) {
        updateProgress(for: item) { progress in
            progress.note = note
        }
    }

    func markSection(_ section: StudySection, completed: Bool) {
        section.items.forEach { item in
            updateProgress(for: item) { progress in
                progress.isCompleted = completed
                progress.completedAt = completed ? Date() : nil
            }
        }
    }

    func resetProgress() {
        guard let libraryID = selectedLibrary?.id else { return }
        progressByLibraryID[libraryID] = [:]
        items = items.map { item in
            var updated = item
            updated.progress = ItemProgress()
            return updated
        }
        save()
    }

    func openItem(_ item: TrackableItem) {
        guard item.absolutePath.isEmpty == false else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: item.absolutePath))
        updateProgress(for: item) { progress in
            progress.lastOpenedAt = Date()
            if markCompleteWhenOpened {
                progress.isCompleted = true
                progress.completedAt = Date()
            }
        }
    }

    func previewItem(_ item: TrackableItem) {
        guard item.absolutePath.isEmpty == false else { return }
        QuickLookService.shared.preview(URL(fileURLWithPath: item.absolutePath))
    }

    func openNextUnfinished() {
        guard let item = nextUnfinishedItem else { return }
        openItem(item)
    }

    func exportProgressJSON() {
        guard let library = selectedLibrary else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(library.name)-progress.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let payload = ExportPayload(library: library, items: items)
        if let data = try? JSONEncoder.studyTracker.encode(payload) {
            try? data.write(to: url, options: [.atomic])
        }
    }

    func exportProgressCSV() {
        guard let library = selectedLibrary else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(library.name)-progress.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var rows = ["Path,Kind,Completed,Favorite,Last Opened,Note"]
        rows += sorted(items).map { item in
            [
                item.relativePath,
                item.kind.label,
                item.progress.isCompleted ? "true" : "false",
                item.progress.isFavorite ? "true" : "false",
                item.progress.lastOpenedAt?.ISO8601Format() ?? "",
                item.progress.note
            ].map(Self.csvEscape).joined(separator: ",")
        }
        try? rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    func revealItemInFinder(_ item: TrackableItem) {
        guard item.absolutePath.isEmpty == false else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.absolutePath)])
    }

    func saveGeminiAPIKey(_ key: String) {
        do {
            try KeychainService.saveGeminiAPIKey(key)
            refreshGeminiKeyStatus()
            aiStatusMessage = "Gemini API key saved."
        } catch {
            aiStatusMessage = error.localizedDescription
        }
    }

    func removeGeminiAPIKey() {
        do {
            try KeychainService.deleteGeminiAPIKey()
            refreshGeminiKeyStatus()
            aiStatusMessage = "Gemini API key removed."
        } catch {
            aiStatusMessage = error.localizedDescription
        }
    }

    func refreshGeminiKeyStatus() {
        hasGeminiAPIKey = ((try? KeychainService.geminiAPIKey()) ?? nil)?.isEmpty == false
    }

    func testGeminiConnection() async {
        do {
            guard let apiKey = try KeychainService.geminiAPIKey(), apiKey.isEmpty == false else {
                aiStatusMessage = "Add a Gemini API key first."
                return
            }
            try await GeminiPlanningService(apiKey: apiKey, model: geminiModel).testConnection()
            aiStatusMessage = "Gemini connection works."
        } catch {
            aiStatusMessage = error.localizedDescription
        }
    }

    func generateAIPlan() async {
        guard let library = selectedLibrary else { return }
        let prompt = aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else {
            aiStatusMessage = "Describe what you want Gemini to plan."
            return
        }
        do {
            guard let apiKey = try KeychainService.geminiAPIKey(), apiKey.isEmpty == false else {
                aiStatusMessage = "Add a Gemini API key in Settings first."
                return
            }
            isGeneratingAIPlan = true
            defer { isGeneratingAIPlan = false }
            let context = AIPlanningContext(
                projectName: library.name,
                projectSummary: "\(completedCount) of \(totalCount) files complete. \(sections.count) sections. \(selectedTodos.count) todos.",
                files: filteredItems.isEmpty ? items : filteredItems,
                todos: selectedTodos
            )
            let draft = try await GeminiPlanningService(apiKey: apiKey, model: geminiModel).generatePlan(prompt: prompt, context: context)
            aiDraft = draft
            selectedAIActionIDs = Set(draft.actions.map(\.id))
            aiStatusMessage = "Review Gemini's draft before applying it."
        } catch {
            aiStatusMessage = error.localizedDescription
        }
    }

    func toggleAIActionSelection(_ action: AIActionDraft) {
        if selectedAIActionIDs.contains(action.id) {
            selectedAIActionIDs.remove(action.id)
        } else {
            selectedAIActionIDs.insert(action.id)
        }
    }

    func applySelectedAIActions() {
        guard let draft = aiDraft else { return }
        let selectedActions = draft.actions.filter { selectedAIActionIDs.contains($0.id) }
        selectedActions.forEach(applyAIAction)
        aiStatusMessage = "Applied \(selectedActions.count) selected AI actions."
        aiDraft = nil
        selectedAIActionIDs.removeAll()
    }

    private func updateProgress(for item: TrackableItem, mutate: (inout ItemProgress) -> Void) {
        guard let libraryID = selectedLibrary?.id else { return }
        var libraryProgress = progressByLibraryID[libraryID] ?? [:]
        var progress = libraryProgress[item.relativePath] ?? item.progress
        mutate(&progress)
        libraryProgress[item.relativePath] = progress
        progressByLibraryID[libraryID] = libraryProgress
        manualItemsByLibraryID[libraryID] = manualItemsByLibraryID[libraryID, default: []].map { existing in
            guard existing.relativePath == item.relativePath else { return existing }
            var updated = existing
            updated.progress = progress
            return updated
        }
        items = items.map { existing in
            guard existing.relativePath == item.relativePath else { return existing }
            var updated = existing
            updated.progress = progress
            return updated
        }
        save()
    }

    private func sorted(_ unsorted: [TrackableItem]) -> [TrackableItem] {
        unsorted.sorted { lhs, rhs in
            switch sortOption {
            case .folderOrder:
                return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
            case .fileName:
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            case .fileType:
                return lhs.kind.label.localizedStandardCompare(rhs.kind.label) == .orderedAscending
            case .duration:
                return (lhs.durationSeconds ?? 0) < (rhs.durationSeconds ?? 0)
            case .completion:
                return lhs.progress.isCompleted == rhs.progress.isCompleted
                    ? lhs.relativePath < rhs.relativePath
                    : !lhs.progress.isCompleted
            case .lastOpened:
                return (lhs.progress.lastOpenedAt ?? .distantPast) > (rhs.progress.lastOpenedAt ?? .distantPast)
            case .dateAdded:
                return lhs.dateAdded > rhs.dateAdded
            case .fileSize:
                return lhs.byteSize > rhs.byteSize
            }
        }
    }

    private func groupKey(for item: TrackableItem) -> String {
        switch groupOption {
        case .folder:
            return folderPath(for: item)
        case .type:
            return item.kind.rawValue
        case .completion:
            return item.progress.isCompleted ? "completed" : "remaining"
        case .dateAdded:
            return Calendar.current.startOfDay(for: item.dateAdded).ISO8601Format()
        case .favorite:
            return item.progress.isFavorite ? "favorites" : "not-favorites"
        }
    }

    private func folderPath(for item: TrackableItem) -> String {
        let path = NSString(string: item.relativePath).deletingLastPathComponent
        return path.isEmpty || path == "." ? "Root" : path
    }

    private func sectionTitle(for key: String) -> String {
        switch groupOption {
        case .folder:
            return key
        case .type:
            return FileKind(rawValue: key)?.label ?? key
        case .completion:
            return key == "completed" ? "Completed" : "Remaining"
        case .dateAdded:
            return "Added \(key.prefix(10))"
        case .favorite:
            return key == "favorites" ? "Favorites" : "Not Favorite"
        }
    }

    private static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func requestText(title: String, message: String, placeholder: String, defaultValue: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = placeholder
        field.stringValue = defaultValue
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func markdownFileURL(for library: Library, section: StudySection?, title: String) throws -> URL {
        let filename = "\(sanitizedPathComponent(title)).md"
        if library.isManual {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = filename
            panel.title = "Save Markdown File"
            panel.prompt = "Create"
            guard panel.runModal() == .OK, let url = panel.url else {
                throw CocoaError(.userCancelled)
            }
            return uniqueFileURL(for: url)
        }

        guard let rootURL = resolveRootURL(for: library) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let didAccess = rootURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                rootURL.stopAccessingSecurityScopedResource()
            }
        }

        var directoryURL = rootURL
        let sectionPath = markdownSectionPath(section)
        if sectionPath.isEmpty == false {
            directoryURL.appendPathComponent(sectionPath, isDirectory: true)
        }
        return uniqueFileURL(for: directoryURL.appendingPathComponent(filename))
    }

    private func addManualMarkdownItem(title: String, fileURL: URL, section: StudySection?) {
        guard let library = selectedLibrary else { return }
        let sectionPath = section?.path ?? defaultManualSectionPath(for: library.id)
        if manualListsByLibraryID[library.id, default: []].contains(sectionPath) == false {
            manualListsByLibraryID[library.id, default: []].append(sectionPath)
        }
        let relativePath = uniqueItemPath(title: title, sectionPath: sectionPath, libraryID: library.id)
        let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        let item = TrackableItem(
            libraryID: library.id,
            title: title,
            relativePath: relativePath,
            absolutePath: fileURL.path,
            fileExtension: "md",
            kind: .markdown,
            byteSize: size,
            durationSeconds: nil,
            pageCount: nil,
            wordCount: 1,
            dateAdded: Date(),
            modifiedAt: Date(),
            progress: ItemProgress()
        )
        manualItemsByLibraryID[library.id, default: []].append(item)
        hiddenItemPathsByLibraryID[library.id, default: []].remove(relativePath)
        expandedSections.insert(sectionPath)
    }

    private func openInPreferredEditor(_ url: URL) {
        guard let applicationPath = preferredEditor.applicationPath else {
            NSWorkspace.shared.open(url)
            return
        }

        let appURL = URL(fileURLWithPath: applicationPath)
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            NSWorkspace.shared.open(url)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
    }

    private func resolveRootURL(for library: Library) -> URL? {
        if let data = library.bookmarkData {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                return url
            }
        }
        guard library.rootPath.isEmpty == false else { return nil }
        return URL(fileURLWithPath: library.rootPath)
    }

    private func markdownSectionPath(_ section: StudySection?) -> String {
        guard groupOption == .folder, let section else { return "Notes" }
        return section.path == "Root" ? "" : section.path
    }

    private func uniqueFileURL(for proposedURL: URL) -> URL {
        let directory = proposedURL.deletingLastPathComponent()
        let base = proposedURL.deletingPathExtension().lastPathComponent
        let ext = proposedURL.pathExtension
        var candidate = proposedURL
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) \(index)").appendingPathExtension(ext)
            index += 1
        }
        return candidate
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func defaultManualSectionPath(for libraryID: UUID) -> String {
        let lists = manualListsByLibraryID[libraryID, default: []]
        if let first = lists.first {
            return first
        }
        return "Manual"
    }

    private func uniqueSectionPath(from name: String, libraryID: UUID) -> String {
        let base = sanitizedPathComponent(name)
        let existing = Set(sections.map(\.path)).union(manualListsByLibraryID[libraryID, default: []])
        guard existing.contains(base) else { return base }
        var index = 2
        while existing.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }

    private func uniqueItemPath(title: String, sectionPath: String, libraryID: UUID) -> String {
        let base = "\(sectionPath)/\(sanitizedPathComponent(title))"
        let existing = Set(items.map(\.relativePath)).union(manualItemsByLibraryID[libraryID, default: []].map(\.relativePath))
        guard existing.contains(base) == false else { return "\(base) \(UUID().uuidString.prefix(6))" }
        return base
    }

    private func sanitizedPathComponent(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyAIAction(_ action: AIActionDraft) {
        switch action.actionType {
        case .createProject:
            let library = Library(
                id: UUID(),
                name: action.title,
                rootPath: "",
                bookmarkData: nil,
                createdAt: Date(),
                lastOpenedAt: Date(),
                scanSettings: ScanSettings(includeHiddenFiles: includeHiddenFiles)
            )
            libraries.insert(library, at: 0)
            selectedLibraryID = library.id
            items = []
            save()
        case .createList:
            addList(named: action.title)
        case .createItem:
            addItem(title: action.title, sectionPath: action.sectionTitle)
        case .createTodo:
            addTodo(title: action.title, detail: action.detail)
        }
    }

    private func aiNote(sectionPath: String) -> String {
        "AI-created item in \(sectionPath)."
    }

    private var storageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("StudyTracker", isDirectory: true).appendingPathComponent("appdata.json")
    }
}

private struct AppData: Codable {
    var libraries: [Library]
    var progressByLibraryID: [UUID: [String: ItemProgress]]
    var manualItemsByLibraryID: [UUID: [TrackableItem]]
    var manualListsByLibraryID: [UUID: [String]]
    var todosByLibraryID: [UUID: [ProjectTodo]]
    var hiddenItemPathsByLibraryID: [UUID: Set<String>]
    var hiddenSectionPathsByLibraryID: [UUID: Set<String>]
    var selectedLibraryID: UUID?
    var includeHiddenFiles: Bool
    var markCompleteWhenOpened: Bool
    var preferredEditor: ExternalEditor
    var geminiModel: String

    init(
        libraries: [Library],
        progressByLibraryID: [UUID: [String: ItemProgress]],
        manualItemsByLibraryID: [UUID: [TrackableItem]],
        manualListsByLibraryID: [UUID: [String]],
        todosByLibraryID: [UUID: [ProjectTodo]],
        hiddenItemPathsByLibraryID: [UUID: Set<String>],
        hiddenSectionPathsByLibraryID: [UUID: Set<String>],
        selectedLibraryID: UUID?,
        includeHiddenFiles: Bool,
        markCompleteWhenOpened: Bool,
        preferredEditor: ExternalEditor,
        geminiModel: String
    ) {
        self.libraries = libraries
        self.progressByLibraryID = progressByLibraryID
        self.manualItemsByLibraryID = manualItemsByLibraryID
        self.manualListsByLibraryID = manualListsByLibraryID
        self.todosByLibraryID = todosByLibraryID
        self.hiddenItemPathsByLibraryID = hiddenItemPathsByLibraryID
        self.hiddenSectionPathsByLibraryID = hiddenSectionPathsByLibraryID
        self.selectedLibraryID = selectedLibraryID
        self.includeHiddenFiles = includeHiddenFiles
        self.markCompleteWhenOpened = markCompleteWhenOpened
        self.preferredEditor = preferredEditor
        self.geminiModel = geminiModel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        libraries = try container.decode([Library].self, forKey: .libraries)
        progressByLibraryID = try container.decode([UUID: [String: ItemProgress]].self, forKey: .progressByLibraryID)
        manualItemsByLibraryID = try container.decodeIfPresent([UUID: [TrackableItem]].self, forKey: .manualItemsByLibraryID) ?? [:]
        manualListsByLibraryID = try container.decodeIfPresent([UUID: [String]].self, forKey: .manualListsByLibraryID) ?? [:]
        todosByLibraryID = try container.decodeIfPresent([UUID: [ProjectTodo]].self, forKey: .todosByLibraryID) ?? [:]
        hiddenItemPathsByLibraryID = try container.decodeIfPresent([UUID: Set<String>].self, forKey: .hiddenItemPathsByLibraryID) ?? [:]
        hiddenSectionPathsByLibraryID = try container.decodeIfPresent([UUID: Set<String>].self, forKey: .hiddenSectionPathsByLibraryID) ?? [:]
        selectedLibraryID = try container.decodeIfPresent(UUID.self, forKey: .selectedLibraryID)
        includeHiddenFiles = try container.decodeIfPresent(Bool.self, forKey: .includeHiddenFiles) ?? false
        markCompleteWhenOpened = try container.decodeIfPresent(Bool.self, forKey: .markCompleteWhenOpened) ?? false
        preferredEditor = try container.decodeIfPresent(ExternalEditor.self, forKey: .preferredEditor) ?? .systemDefault
        geminiModel = try container.decodeIfPresent(String.self, forKey: .geminiModel) ?? "gemini-2.5-flash"
    }
}

private struct ExportPayload: Codable {
    var library: Library
    var items: [TrackableItem]
}

private extension JSONEncoder {
    static var studyTracker: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var studyTracker: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
