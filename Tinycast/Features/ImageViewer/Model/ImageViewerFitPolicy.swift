import Foundation

/// How a photo sits on screen: the window takes the photo's shape, and a photo never upscales to fit.
enum ImageViewerFitPolicy {
    /// Of the display's visible frame, so a large photo stops short of the menu bar and the Dock.
    static let screenShare: CGFloat = 0.9
    /// A tiny image still gets a window you can find and click away from.
    static let minimumWindow = CGSize(width: 320, height: 220)
    static let maximumMagnification: CGFloat = 8
    static let zoomStep: CGFloat = 1.25
    /// Enough pixels for a 2× zoom past a full-screen fit before the decode runs out.
    static let decodeScreenMultiple: CGFloat = 2

    /// Points at the photo's own DPI, which is how a 144-DPI Retina screenshot reads as actual size.
    static func pointSize(pixels: CGSize, dpi: CGSize?) -> CGSize {
        guard let dpi, dpi.width > 0, dpi.height > 0 else { return pixels }
        return CGSize(width: pixels.width * 72 / dpi.width, height: pixels.height * 72 / dpi.height)
    }

    static func fitMagnification(image: CGSize, in bounds: CGSize) -> CGFloat {
        guard image.width > 0, image.height > 0 else { return 1 }
        return min(1, bounds.width / image.width, bounds.height / image.height)
    }

    static func windowSize(image: CGSize, visible: CGSize) -> CGSize {
        let bounds = CGSize(width: visible.width * screenShare, height: visible.height * screenShare)
        let scale = fitMagnification(image: image, in: bounds)
        let width = min(max(image.width * scale, minimumWindow.width), bounds.width)
        let height = min(max(image.height * scale, minimumWindow.height), bounds.height)
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    static func maximum(fit: CGFloat) -> CGFloat {
        max(maximumMagnification, fit)
    }

    static func zoomedIn(_ magnification: CGFloat, fit: CGFloat) -> CGFloat {
        min(magnification * zoomStep, maximum(fit: fit))
    }

    static func zoomedOut(_ magnification: CGFloat, fit: CGFloat) -> CGFloat {
        max(magnification / zoomStep, fit)
    }

    /// A double-click leaves any zoom for the fit, and from the fit goes to actual size.
    static func toggled(_ magnification: CGFloat, fit: CGFloat) -> CGFloat {
        if magnification > fit * 1.01 { return fit }
        return fit < 1 ? 1 : min(fit * 2, maximum(fit: fit))
    }

    /// The long edge to decode at: the photo's own, or what this display can use, whichever is less.
    static func decodeLongEdge(pixels: CGSize, screenPixels: CGSize) -> CGFloat {
        let screen = max(screenPixels.width, screenPixels.height) * decodeScreenMultiple
        return min(max(pixels.width, pixels.height), screen)
    }
}
