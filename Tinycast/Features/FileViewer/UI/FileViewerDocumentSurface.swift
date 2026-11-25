import AppKit
import QuickLookUI
import WebKit

/// Quick Look's own drawing of a document, its page widened to the window and zoomed on request.
final class FileViewerDocumentSurface: NSView, FileViewerSurface {
    /// Quick Look reports no load, so its view is looked for until this gives up.
    private static let loadLimit = Duration.seconds(10)
    private static let loadPoll = Duration.milliseconds(16)

    private let preview: QLPreviewView
    private var fit: CGFloat = 1
    private var loading: Task<Void, Never>?

    init(url: URL, size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        preview = QLPreviewView(frame: bounds, style: .normal) ?? QLPreviewView(frame: bounds)
        super.init(frame: bounds)
        preview.autoresizingMask = [.width, .height]
        // Its default closes with the window, which is mid-fade when the panel orders out.
        preview.shouldCloseWithWindow = false
        preview.autostarts = false
        addSubview(preview)
        preview.previewItem = url as NSURL
        loading = Task { [weak self] in await self?.adopt() }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Focus, so the arrow and page keys turn slides and scroll.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(preview)
    }

    func zoomIn() {
        zoom { ImageViewerFitPolicy.zoomedIn($0, fit: $1) }
    }

    func zoomOut() {
        zoom { ImageViewerFitPolicy.zoomedOut($0, fit: $1) }
    }

    /// A page narrower than the window would hug its left edge, so the fit is as small as it gets.
    func zoomToActualSize() {
        zoomToFit()
    }

    func zoomToFit() {
        zoom { $1 }
    }

    func close() {
        loading?.cancel()
        loading = nil
        preview.close()
    }

    /// Word, Excel and HTML draw in a web view, rich text in a scroll view, slides in neither.
    private var page: WKWebView? { preview.firstDescendant() }
    private var textScroller: NSScrollView? { preview.firstDescendant() }

    private func zoom(_ step: (_ current: CGFloat, _ fit: CGFloat) -> CGFloat) {
        if let page {
            page.pageZoom = step(page.pageZoom, fit)
        } else if let textScroller {
            textScroller.setMagnification(
                step(textScroller.magnification, fit),
                centeredAt: CGPoint(x: 0, y: textScroller.documentVisibleRect.minY))
            // Narrowed to what the zoom leaves in view, so the lines rewrap rather than run off.
            textScroller.documentView?.setFrameSize(
                CGSize(
                    width: textScroller.contentView.bounds.width,
                    height: textScroller.documentView?.frame.height ?? 0))
        }
    }

    private func adopt() async {
        let deadline = ContinuousClock.now + Self.loadLimit
        while !Task.isCancelled, ContinuousClock.now < deadline {
            if let page, page.frame.width > 0 {
                widen(page)
                window?.makeFirstResponder(page)
                return
            }
            if let textScroller {
                textScroller.minMagnification = fit
                textScroller.maxMagnification = ImageViewerFitPolicy.maximumMagnification
                if let textView = textScroller.documentView as? NSTextView {
                    textView.textContainerInset = CGSize(
                        width: Theme.Spacing.xxl, height: Theme.Spacing.xxl)
                    // Autoresizing compounds with a magnified clip view; `zoom` sets the width.
                    textView.autoresizingMask = []
                    textView.scroll(.zero)
                }
                window?.makeFirstResponder(textScroller.documentView)
                return
            }
            try? await Task.sleep(for: Self.loadPoll)
        }
    }

    /// Quick Look centres a Word page in a 625pt column that a zoom would only clip.
    private func widen(_ page: WKWebView) {
        guard let host = page.superview, host.bounds.width > page.frame.width else { return }
        fit = host.bounds.width / page.frame.width
        NSLayoutConstraint.deactivate(
            host.constraints.filter { $0.firstItem === page || $0.secondItem === page })
        page.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            page.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            page.topAnchor.constraint(equalTo: host.topAnchor),
            page.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        page.pageZoom = fit
    }
}

extension NSView {
    fileprivate func firstDescendant<View: NSView>() -> View? {
        for subview in subviews {
            if let match = subview as? View { return match }
            if let match: View = subview.firstDescendant() { return match }
        }
        return nil
    }
}
