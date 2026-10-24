import AppKit

/// The photo in a magnifying scroll view: AppKit pinches and scrolls, the zoom steps live here.
final class ImageViewerCanvas: NSScrollView {
    private let imageView = PhotoView()
    private var fit: CGFloat = 1

    init() {
        super.init(frame: .zero)
        contentView = CenteringClipView()
        drawsBackground = false
        contentView.drawsBackground = false
        hasVerticalScroller = true
        hasHorizontalScroller = true
        autohidesScrollers = true
        scrollerStyle = .overlay
        allowsMagnification = true
        imageView.imageScaling = .scaleAxesIndependently
        imageView.animates = true
        documentView = imageView
    }

    required init?(coder: NSCoder) { fatalError() }

    /// `bounds` is the window's content size, since the hosting view has yet to lay this view out.
    func show(_ photo: ImageViewerPhoto, named name: String, in bounds: CGSize) {
        imageView.image = photo.image
        imageView.frame = CGRect(origin: .zero, size: photo.size)
        imageView.setAccessibilityLabel(name)
        fit = ImageViewerFitPolicy.fitMagnification(image: photo.size, in: bounds)
        minMagnification = fit
        maxMagnification = ImageViewerFitPolicy.maximum(fit: fit)
        magnification = fit
    }

    func zoomIn() {
        zoom(to: ImageViewerFitPolicy.zoomedIn(magnification, fit: fit))
    }

    func zoomOut() {
        zoom(to: ImageViewerFitPolicy.zoomedOut(magnification, fit: fit))
    }

    func zoomToActualSize() {
        zoom(to: 1)
    }

    func zoomToFit() {
        zoom(to: fit)
    }

    /// At the fit there is nothing to pan, so a drag moves the window instead.
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            let point = imageView.convert(event.locationInWindow, from: nil)
            setMagnification(ImageViewerFitPolicy.toggled(magnification, fit: fit), centeredAt: point)
        } else if !isZoomedPastFit {
            window?.performDrag(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isZoomedPastFit else { return }
        let bounds = contentView.bounds
        let moved = bounds.offsetBy(
            dx: -event.deltaX / magnification, dy: event.deltaY / magnification)
        contentView.scroll(to: contentView.constrainBoundsRect(moved).origin)
        reflectScrolledClipView(contentView)
    }

    private var isZoomedPastFit: Bool { magnification > fit * 1.01 }

    /// About the middle of what is on screen, so a keyboard zoom keeps the spot you were looking at.
    private func zoom(to target: CGFloat) {
        let visible = documentVisibleRect
        setMagnification(target, centeredAt: CGPoint(x: visible.midX, y: visible.midY))
    }
}

/// Hands every click to the canvas, which owns the double-click zoom and the drag.
private final class PhotoView: NSImageView {
    override func mouseDown(with event: NSEvent) {
        nextResponder?.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        nextResponder?.mouseDragged(with: event)
    }
}

/// A photo smaller than the window sits in its middle rather than in the bottom-left corner.
private final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let document = documentView?.frame else { return rect }
        if rect.width > document.width { rect.origin.x = (document.width - rect.width) / 2 }
        if rect.height > document.height { rect.origin.y = (document.height - rect.height) / 2 }
        return rect
    }
}
