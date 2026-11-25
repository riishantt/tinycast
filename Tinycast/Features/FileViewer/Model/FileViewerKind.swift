import Foundation
import UniformTypeIdentifiers

/// What draws a file: the photo canvas, WebKit, the text view, or Quick Look for anything richer.
enum FileViewerKind: Equatable, Sendable {
    case photo
    case pdf
    case text
    case document

    /// Past this a file goes to Quick Look, which reads only as much as it draws.
    static let textLimit = 8 * 1024 * 1024

    /// Text underneath, but read as a page, a table or a card rather than as source.
    private static let drawnTypes: [UTType] = [
        .rtf, .html, .commaSeparatedText, .vCard, .calendarEvent
    ]

    /// `bytes` is the whole file, or nil when it is a package or over `textLimit`.
    init(type: UTType?, bytes: Data?) {
        if let type, type.conforms(to: .image) {
            // ImageIO reads no SVG.
            self = type.conforms(to: .svg) ? .document : .photo
        } else if let type, type.conforms(to: .pdf) {
            self = .pdf
        } else if let type, Self.drawnTypes.contains(where: type.conforms) {
            self = .document
        } else if let bytes, FileSearchPreviewKind.isText(bytes, isWholeFile: true) {
            self = .text
        } else {
            self = .document
        }
    }
}
