import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// A file made ready to show; a document stays on disk for Quick Look to read.
enum FileViewerContent: Sendable {
    case photo(ImageViewerPhoto)
    case pdf(FileViewerDocumentShape, isLocked: Bool)
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
        let mayBeText = FileViewerKind(type: type, bytes: nil) == .document
        let bytes =
            values.isRegularFile == true && isSmall && mayBeText ? try? Data(contentsOf: url) : nil
        switch FileViewerKind(type: type, bytes: bytes) {
        case .photo:
            return ImageViewerPhoto.decode(url, screenPixels: screenPixels).map(FileViewerContent.photo)
        case .pdf: return pdf(url)
        case .text: return .text(String(decoding: bytes ?? Data(), as: UTF8.self))
        case .document: return .document(FileViewerDocumentShape(type: type))
        }
    }

    /// A locked PDF has no pages to measure until the viewer takes its password.
    private static func pdf(_ url: URL) -> FileViewerContent? {
        guard let document = CGPDFDocument(url as CFURL) else { return nil }
        guard document.isUnlocked else { return .pdf(.page, isLocked: true) }
        guard let page = document.page(at: 1) else { return nil }
        let box = page.getBoxRect(.cropBox).size
        let isTurned = page.rotationAngle % 180 != 0
        let firstPage = isTurned ? CGSize(width: box.height, height: box.width) : box
        return .pdf(FileViewerDocumentShape(firstPage: firstPage), isLocked: false)
    }
}
