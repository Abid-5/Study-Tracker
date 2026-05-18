import Foundation

enum FileKindResolver {
    static func kind(for fileExtension: String) -> FileKind {
        switch fileExtension.lowercased() {
        case "mp4", "m4v", "mov", "mkv", "avi", "webm": .video
        case "mp3", "m4a", "aac", "wav", "flac", "aiff": .audio
        case "pdf": .pdf
        case "md", "markdown": .markdown
        case "ppt", "pptx", "key": .presentation
        case "doc", "docx", "rtf", "txt": .document
        case "xls", "xlsx", "csv", "numbers": .spreadsheet
        case "swift", "js", "ts", "tsx", "jsx", "py", "java", "c", "cpp", "h", "html", "css", "json", "yaml", "yml", "xml": .code
        case "zip", "rar", "7z", "tar", "gz": .archive
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "tiff": .image
        default: .other
        }
    }
}
