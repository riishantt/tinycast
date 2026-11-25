import Foundation
import UniformTypeIdentifiers

/// A file made ready to show; a document stays on disk for Quick Look to read.
enum FileViewerContent: Sendable {
    case photo(ImageViewerPhoto)
    case text(String)
    case document(FileViewerDocumentShape)

    static func load(_ url: URL, screenPixels: CGSize) async -> FileViewerContent? {
        await Task.detached(priority: .userInitiated) {
            read(url, screenPixels: screenPixels)
        }.value
    }

    private static func read(_ url: URL, screenPixels: CGSize) -> FileViewerContent? {
        guard FileManager.default.isReadableFile(atPath: url.path),
            let values = try? url.resourceValues(forKeys: [
                .contentTypeKey, .fileSizeKey, .isRegularFileKey
            ])
        else { return nil }
        let type = values.contentType
        let isSmall = (values.fileSize ?? .max) <= FileViewerKind.textLimit
        let isPhoto = FileViewerKind(type: type, bytes: nil) == .photo
        let bytes =
            values.isRegularFile == true && isSmall && !isPhoto ? try? Data(contentsOf: url) : nil
        switch FileViewerKind(type: type, bytes: bytes) {
        case .photo:
            return ImageViewerPhoto.decode(url, screenPixels: screenPixels).map(FileViewerContent.photo)
        case .text: return .text(String(decoding: bytes ?? Data(), as: UTF8.self))
        case .document: return .document(FileViewerDocumentShape(type: type))
        }
    }
}
