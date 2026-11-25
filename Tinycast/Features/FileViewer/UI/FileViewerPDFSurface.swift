import AppKit
import WebKit

/// A PDF in WebKit's process, which exits with it; PDFKit here would load Vision's models for good.
final class FileViewerPDFSurface: WKWebView, WKNavigationDelegate, FileViewerSurface {
    /// WebKit's 1 is the page at the window's width, so this shows about two pages of a portrait PDF.
    private static let smallestZoom: CGFloat = 0.5

    let takesTyping: Bool

    /// A locked PDF asks for its password in a field of its own.
    init(url: URL, isLocked: Bool, size: CGSize) {
        takesTyping = isLocked
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        super.init(frame: CGRect(origin: .zero, size: size), configuration: configuration)
        navigationDelegate = self
        allowsMagnification = true
        loadFileURL(url, allowingReadAccessTo: url)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Focus, so the arrow and page keys scroll and a selection copies.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    func zoomIn() {
        pageZoom = ImageViewerFitPolicy.zoomedIn(pageZoom, fit: 1)
    }

    func zoomOut() {
        pageZoom = ImageViewerFitPolicy.zoomedOut(pageZoom, fit: Self.smallestZoom)
    }

    func zoomToActualSize() {
        zoomToFit()
    }

    func zoomToFit() {
        pageZoom = 1
    }

    func close() {
        stopLoading()
        navigationDelegate = nil
    }

    /// A link opens in the browser rather than replacing the PDF.
    func webView(
        _ webView: WKWebView, decidePolicyFor action: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard action.navigationType == .linkActivated, let link = action.request.url, !link.isFileURL
        else { return action.request.url?.isFileURL == true ? .allow : .cancel }
        NSWorkspace.shared.open(link)
        return .cancel
    }
}
