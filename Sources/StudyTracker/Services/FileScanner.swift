import AVFoundation
import Foundation
import PDFKit

struct FileScanner {
    func scan(library: Library, existingProgress: [String: ItemProgress]) async -> [TrackableItem] {
        guard let rootURL = resolveRootURL(for: library) else { return [] }
        let didAccess = rootURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                rootURL.stopAccessingSecurityScopedResource()
            }
        }

        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isPackageKey,
            .isHiddenKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]

        let options: FileManager.DirectoryEnumerationOptions = library.scanSettings.includePackages ? [] : [.skipsPackageDescendants]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(keys),
            options: options,
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var items: [TrackableItem] = []
        while let fileURL = enumerator.nextObject() as? URL {
            guard shouldInclude(fileURL, settings: library.scanSettings) else { continue }
            guard let values = try? fileURL.resourceValues(forKeys: keys) else { continue }
            if values.isDirectory == true { continue }
            if values.isRegularFile != true { continue }
            if values.isHidden == true, library.scanSettings.includeHiddenFiles == false { continue }
            if values.isPackage == true, library.scanSettings.includePackages == false { continue }

            let relativePath = Self.relativePath(for: fileURL, rootURL: rootURL)
            let fileExtension = fileURL.pathExtension.lowercased()
            let kind = FileKindResolver.kind(for: fileExtension)
            let metadata = await metadata(for: fileURL, kind: kind)
            let progress = existingProgress[relativePath] ?? ItemProgress()

            items.append(
                TrackableItem(
                    libraryID: library.id,
                    title: fileURL.deletingPathExtension().lastPathComponent,
                    relativePath: relativePath,
                    absolutePath: fileURL.path,
                    fileExtension: fileExtension,
                    kind: kind,
                    byteSize: Int64(values.fileSize ?? 0),
                    durationSeconds: metadata.durationSeconds,
                    pageCount: metadata.pageCount,
                    wordCount: metadata.wordCount,
                    dateAdded: library.createdAt,
                    modifiedAt: values.contentModificationDate,
                    progress: progress
                )
            )
        }

        return items.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
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
        return URL(fileURLWithPath: library.rootPath)
    }

    private func shouldInclude(_ url: URL, settings: ScanSettings) -> Bool {
        let name = url.lastPathComponent
        if settings.includeHiddenFiles == false, name.hasPrefix(".") {
            return false
        }
        if settings.enabledExtensions.isEmpty {
            return true
        }
        return settings.enabledExtensions.contains(url.pathExtension.lowercased())
    }

    private func metadata(for url: URL, kind: FileKind) async -> (durationSeconds: Double?, pageCount: Int?, wordCount: Int?) {
        switch kind {
        case .video, .audio:
            let asset = AVURLAsset(url: url)
            if let duration = try? await asset.load(.duration) {
                return (duration.seconds.isFinite ? duration.seconds : nil, nil, nil)
            }
            return (nil, nil, nil)
        case .pdf:
            return (nil, PDFDocument(url: url)?.pageCount, nil)
        case .markdown, .document, .code:
            return (nil, nil, wordCount(for: url))
        default:
            return (nil, nil, nil)
        }
    }

    private func wordCount(for url: URL) -> Int? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]), data.count <= 2_000_000 else {
            return nil
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            return nil
        }
        return text.split { $0.isWhitespace || $0.isNewline }.count
    }

    static func relativePath(for fileURL: URL, rootURL: URL) -> String {
        let root = rootURL.standardizedFileURL.path
        let path = fileURL.standardizedFileURL.path
        guard path.hasPrefix(root) else { return fileURL.lastPathComponent }
        let start = path.index(path.startIndex, offsetBy: min(root.count + 1, path.count))
        return String(path[start...])
    }
}
