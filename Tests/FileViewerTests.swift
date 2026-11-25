import CoreGraphics
import Foundation
import UniformTypeIdentifiers

@main
struct FileViewerTests {
    static func main() {
        var failures = 0

        func check(_ description: String, _ condition: @autoclosure () -> Bool) {
            if condition() {
                print("PASS  \(description)")
            } else {
                print("FAIL  \(description)")
                failures += 1
            }
        }

        let screen = CGSize(width: 1512, height: 944)
        let bounds = CGSize(
            width: screen.width * ImageViewerFitPolicy.screenShare,
            height: screen.height * ImageViewerFitPolicy.screenShare)

        // The window takes the photo's shape: a portrait photo gets a tall, narrow window.
        let portrait = ImageViewerFitPolicy.windowSize(
            image: CGSize(width: 3024, height: 4032), visible: screen)
        check("a portrait photo fills the height", portrait.height == bounds.height.rounded())
        check("a portrait window is narrower than tall", portrait.width < portrait.height)
        check(
            "a portrait window keeps the photo's shape",
            abs(portrait.width / portrait.height - 3024 / 4032) < 0.01)

        let landscape = ImageViewerFitPolicy.windowSize(
            image: CGSize(width: 4032, height: 3024), visible: screen)
        check("a landscape window is wider than tall", landscape.width > landscape.height)
        check("a large photo never outgrows the screen share", landscape.width <= bounds.width)

        let small = CGSize(width: 600, height: 400)
        check(
            "a photo that fits shows at actual size",
            ImageViewerFitPolicy.windowSize(image: small, visible: screen) == small)
        check(
            "a photo that fits is never magnified",
            ImageViewerFitPolicy.fitMagnification(image: small, in: bounds) == 1)

        let tiny = ImageViewerFitPolicy.windowSize(
            image: CGSize(width: 16, height: 16), visible: screen)
        check("an icon still gets a findable window", tiny == ImageViewerFitPolicy.minimumWindow)

        let banner = ImageViewerFitPolicy.windowSize(
            image: CGSize(width: 1200, height: 40), visible: screen)
        check("a thin banner keeps the minimum height", banner.height == 220)
        check("a thin banner shows at its width", banner.width == 1200)

        check(
            "a Retina screenshot's actual size is half its pixels",
            ImageViewerFitPolicy.pointSize(
                pixels: CGSize(width: 2880, height: 1800), dpi: CGSize(width: 144, height: 144))
                == CGSize(width: 1440, height: 900))
        check(
            "no DPI means a pixel per point",
            ImageViewerFitPolicy.pointSize(pixels: small, dpi: nil) == small)
        check(
            "a zero DPI is ignored",
            ImageViewerFitPolicy.pointSize(pixels: small, dpi: .zero) == small)
        check(
            "an empty image fits at 1",
            ImageViewerFitPolicy.fitMagnification(image: .zero, in: bounds) == 1)

        // Zooming out never goes past the fit, and zooming in stops at the ceiling.
        let fit: CGFloat = 0.25
        check("zoom out stops at the fit", ImageViewerFitPolicy.zoomedOut(fit, fit: fit) == fit)
        check("zoom in steps up", ImageViewerFitPolicy.zoomedIn(fit, fit: fit) > fit)
        let ceiling = ImageViewerFitPolicy.maximumMagnification
        check(
            "zoom in stops at the ceiling",
            ImageViewerFitPolicy.zoomedIn(ceiling, fit: fit) == ceiling)
        check(
            "in and out return to where they started",
            abs(
                ImageViewerFitPolicy.zoomedOut(
                    ImageViewerFitPolicy.zoomedIn(0.5, fit: fit), fit: fit) - 0.5) < 0.0001)

        check(
            "a double-click from the fit goes to actual size",
            ImageViewerFitPolicy.toggled(fit, fit: fit) == 1)
        check(
            "a double-click while zoomed returns to the fit",
            ImageViewerFitPolicy.toggled(3, fit: fit) == fit)
        check(
            "a double-click on a photo shown at actual size doubles it",
            ImageViewerFitPolicy.toggled(1, fit: 1) == 2)

        check(
            "a phone photo decodes at its own size on a Retina display",
            ImageViewerFitPolicy.decodeLongEdge(
                pixels: CGSize(width: 4032, height: 3024),
                screenPixels: CGSize(width: 3024, height: 1964)) == 4032)
        check(
            "a huge photo decodes at twice the display",
            ImageViewerFitPolicy.decodeLongEdge(
                pixels: CGSize(width: 12000, height: 9000),
                screenPixels: CGSize(width: 3024, height: 1964)) == 6048)

        func kind(_ pathExtension: String, _ bytes: Data? = nil) -> FileViewerKind {
            FileViewerKind(type: UTType(filenameExtension: pathExtension), bytes: bytes)
        }
        let source = Data("let x = 1\n".utf8)
        let zipped = Data([0x50, 0x4B, 0x03, 0x04, 0x00])
        check("a photo goes to the canvas", kind("heic") == .photo)
        check("an SVG goes to Quick Look, as ImageIO reads none", kind("svg", source) == .document)
        check("plain text reads as text", kind("txt", source) == .text)
        check("an empty text file reads as text", kind("txt", Data()) == .text)
        check("source reads as text", kind("swift", source) == .text)
        check("text of an undeclared type reads as text", kind("ipynb", source) == .text)
        check("text with no type reads as text", FileViewerKind(type: nil, bytes: source) == .text)
        check("text too large to hold goes to Quick Look", kind("log") == .document)
        check("a Word file goes to Quick Look", kind("docx", zipped) == .document)
        check("a UTF-16 file goes to Quick Look", kind("txt", Data([0xFF, 0xFE, 0x61, 0x00])) == .document)
        for drawn in ["rtf", "html", "csv", "vcf", "ics"] {
            check("a .\(drawn) is drawn, not shown as source", kind(drawn, source) == .document)
        }

        func shape(_ pathExtension: String) -> FileViewerDocumentShape {
            FileViewerDocumentShape(type: UTType(filenameExtension: pathExtension))
        }
        check("a Word file is a page", shape("docx") == .page)
        check("an Excel file is a sheet", shape("xlsx") == .sheet)
        check("a CSV is a sheet", shape("csv") == .sheet)
        check("a PowerPoint file is slides", shape("pptx") == .slides)
        for shape in [FileViewerDocumentShape.page, .sheet, .slides] {
            for visible in [screen, CGSize(width: 640, height: 400), CGSize(width: 900, height: 1600)] {
                let size = shape.windowSize(visible: visible)
                check(
                    "a \(shape) window stays inside \(Int(visible.width))pt",
                    size.width <= (visible.width * ImageViewerFitPolicy.screenShare).rounded()
                        && size.height <= (visible.height * ImageViewerFitPolicy.screenShare).rounded())
            }
        }
        let slides = FileViewerDocumentShape.slides.windowSize(visible: screen)
        check("slides open widescreen", abs(slides.width / slides.height - 16 / 9) < 0.01)

        // Claiming a supertype of PDF in Info.plist would offer Tinycast for every PDF.
        let claimed = claimedTypes()
        check("Info.plist claims document types", claimed.count > 1)
        check("no claimed type takes PDFs", !claimed.contains { UTType.pdf.conforms(to: $0) })
        for pathExtension in ["docx", "doc", "rtf", "odt", "xlsx", "xls", "csv", "pptx", "ppt", "txt", "md"] {
            let type = UTType(filenameExtension: pathExtension) ?? .data
            check("Info.plist claims .\(pathExtension)", claimed.contains { type.conforms(to: $0) })
        }

        print(failures == 0 ? "all passed" : "\(failures) failed")
        if failures > 0 { exit(1) }
    }

    private static func claimedTypes() -> [UTType] {
        guard let data = FileManager.default.contents(atPath: "Tinycast/Info.plist"),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any],
            let claims = plist["CFBundleDocumentTypes"] as? [[String: Any]]
        else { return [] }
        return claims.flatMap { $0["LSItemContentTypes"] as? [String] ?? [] }.compactMap { UTType($0) }
    }
}
