import CoreGraphics
import UniformTypeIdentifiers

/// Quick Look reports no page size, so a document's window takes the shape its kind usually has.
enum FileViewerDocumentShape: Equatable, Sendable {
    case page
    case sheet
    case slides

    init(type: UTType?) {
        if let type, type.conforms(to: .presentation) {
            self = .slides
        } else if let type, type.conforms(to: .spreadsheet) || type.conforms(to: .commaSeparatedText) {
            self = .sheet
        } else {
            self = .page
        }
    }

    init(firstPage: CGSize) {
        self = firstPage.width > firstPage.height ? .slides : .page
    }

    func windowSize(visible: CGSize) -> CGSize {
        let share = ImageViewerFitPolicy.screenShare
        let bounds = CGSize(width: visible.width * share, height: visible.height * share)
        let size =
            switch self {
            case .page: CGSize(width: min(860, bounds.width), height: bounds.height)
            case .sheet: CGSize(width: min(1240, bounds.width), height: bounds.height)
            case .slides: Self.widescreen(in: bounds)
            }
        return CGSize(width: size.width.rounded(), height: size.height.rounded())
    }

    private static func widescreen(in bounds: CGSize) -> CGSize {
        let width = min(1280, bounds.width, bounds.height * 16 / 9)
        return CGSize(width: width, height: width * 9 / 16)
    }
}
