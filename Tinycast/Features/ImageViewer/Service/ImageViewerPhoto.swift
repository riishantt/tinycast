import AppKit
import ImageIO
import UniformTypeIdentifiers

/// One photo, decoded off main at what the display can use; only a GIF keeps its frames.
struct ImageViewerPhoto: @unchecked Sendable {
    /// Built off main and never mutated after, which is what makes the `NSImage` safe to hand over.
    let image: NSImage
    /// In points at the photo's own DPI, which is what actual size means.
    let size: CGSize

    static func load(_ url: URL, screenPixels: CGSize) async -> ImageViewerPhoto? {
        await Task.detached(priority: .userInitiated) {
            decode(url, screenPixels: screenPixels)
        }.value
    }

    private static func decode(_ url: URL, screenPixels: CGSize) -> ImageViewerPhoto? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
            let width = number(properties[kCGImagePropertyPixelWidth]),
            let height = number(properties[kCGImagePropertyPixelHeight])
        else { return nil }
        let pixels =
            isRotated(properties)
            ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
        let size = ImageViewerFitPolicy.pointSize(pixels: pixels, dpi: dpi(properties))
        if isAnimated(source) {
            return NSImage(contentsOf: url).map { ImageViewerPhoto(image: $0, size: size) }
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize:
                ImageViewerFitPolicy.decodeLongEdge(pixels: pixels, screenPixels: screenPixels)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return ImageViewerPhoto(image: NSImage(cgImage: cgImage, size: size), size: size)
    }

    private static func number(_ value: Any?) -> CGFloat? {
        (value as? NSNumber).map { CGFloat($0.doubleValue) }
    }

    /// EXIF orientations 5 through 8 turn the stored pixels a quarter turn.
    private static func isRotated(_ properties: [CFString: Any]) -> Bool {
        guard let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue
        else { return false }
        return (5...8).contains(orientation)
    }

    private static func dpi(_ properties: [CFString: Any]) -> CGSize? {
        guard let width = number(properties[kCGImagePropertyDPIWidth]),
            let height = number(properties[kCGImagePropertyDPIHeight])
        else { return nil }
        return CGSize(width: width, height: height)
    }

    private static func isAnimated(_ source: CGImageSource) -> Bool {
        guard CGImageSourceGetCount(source) > 1, let type = CGImageSourceGetType(source) else {
            return false
        }
        return UTType(type as String)?.conforms(to: .gif) == true
    }
}
