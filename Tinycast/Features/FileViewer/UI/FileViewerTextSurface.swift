import AppKit

/// Plain text and source, selectable and read-only; zoom changes the type size, so lines rewrap.
final class FileViewerTextSurface: NSScrollView, FileViewerSurface {
    private static let fontSize: CGFloat = 13
    private static let scales: ClosedRange<CGFloat> = 0.6...4

    private let textView = NSTextView(usingTextLayoutManager: true)
    private var scale: CGFloat = 1

    init(text: String, named name: String, size: CGSize) {
        super.init(frame: CGRect(origin: .zero, size: size))
        drawsBackground = false
        contentView.drawsBackground = false
        hasVerticalScroller = true
        autohidesScrollers = true
        scrollerStyle = .overlay
        textView.frame = CGRect(origin: .zero, size: size)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.maxSize = CGSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.drawsBackground = false
        textView.isEditable = false
        textView.isRichText = false
        textView.textContainerInset = CGSize(width: Theme.Spacing.xxl, height: Theme.Spacing.xxl)
        textView.textColor = .textColor
        textView.string = text
        textView.setAccessibilityLabel(name)
        documentView = textView
        setScale(1)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Focus, so the arrow and page keys scroll and a selection copies.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(textView)
    }

    func zoomIn() {
        setScale(scale * ImageViewerFitPolicy.zoomStep)
    }

    func zoomOut() {
        setScale(scale / ImageViewerFitPolicy.zoomStep)
    }

    func zoomToActualSize() {
        setScale(1)
    }

    func zoomToFit() {
        setScale(1)
    }

    func close() {}

    private func setScale(_ target: CGFloat) {
        scale = min(max(target, Self.scales.lowerBound), Self.scales.upperBound)
        textView.font = .monospacedSystemFont(ofSize: Self.fontSize * scale, weight: .regular)
    }
}
