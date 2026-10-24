import CoreGraphics
import Foundation

@main
struct ImageViewerTest {
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

        print(failures == 0 ? "all passed" : "\(failures) failed")
        if failures > 0 { exit(1) }
    }
}
