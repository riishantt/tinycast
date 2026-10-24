import AppKit
import SwiftUI

/// Owns the photo viewer: one panel at a time, for the photo Finder or Search Files handed over.
@MainActor
final class ImageViewerCoordinator {
    private unowned let core: AppCore
    private var panel: ImageViewerPanel?
    private var canvas: ImageViewerCanvas?
    private var shown: URL?
    private var loading: Task<Void, Never>?

    init(core: AppCore) {
        self.core = core
    }

    /// The display is read now, at the click, so a slow decode still lands where the user was.
    func open(_ url: URL) {
        loading?.cancel()
        guard let screen = NSScreen.underCursor else { return }
        let visible = screen.visibleFrame
        let screenPixels = screen.convertRectToBacking(screen.frame).size
        loading = Task { [weak self] in
            let photo = await ImageViewerPhoto.load(url, screenPixels: screenPixels)
            guard let self, !Task.isCancelled else { return }
            loading = nil
            guard let photo else {
                core.showMessage(
                    String(localized: "Couldn’t Open \(url.lastPathComponent)"), tone: .danger)
                return
            }
            present(photo, of: url, in: visible)
        }
    }

    func close() {
        loading?.cancel()
        loading = nil
        guard let closing = panel else { return }
        panel = nil
        canvas = nil
        shown = nil
        closing.onCommand = nil
        closing.orderOutAnimated {}
    }

    private func present(_ photo: ImageViewerPhoto, of url: URL, in visible: CGRect) {
        let size = ImageViewerFitPolicy.windowSize(image: photo.size, visible: visible.size)
        let frame = CGRect(
            x: (visible.midX - size.width / 2).rounded(),
            y: (visible.midY - size.height / 2).rounded(),
            width: size.width, height: size.height)
        let panel = panel ?? makePanel()
        panel.setFrame(frame, display: false)
        canvas?.show(photo, named: url.lastPathComponent, in: size)
        shown = url
        // Non-activating like the palette: key focus without pulling the user out of Finder.
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func makePanel() -> ImageViewerPanel {
        let canvas = ImageViewerCanvas()
        let hosting = NSHostingView(rootView: ImageViewerView(canvas: canvas))
        hosting.sizingOptions = []
        let panel = ImageViewerPanel(content: hosting)
        panel.onCommand = { [weak self] command in self?.perform(command) }
        self.canvas = canvas
        self.panel = panel
        return panel
    }

    private func perform(_ command: ImageViewerPanel.Command) {
        switch command {
        case .close: close()
        case .zoomIn: canvas?.zoomIn()
        case .zoomOut: canvas?.zoomOut()
        case .actualSize: canvas?.zoomToActualSize()
        case .fit: canvas?.zoomToFit()
        case .trash: trash()
        }
    }

    /// No confirmation, as in Finder and Preview: the Trash is the undo.
    private func trash() {
        guard let url = shown else { return }
        close()
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                }.value
                core.showMessage(String(localized: "Moved to Trash"))
            } catch {
                await core.showNotice(
                    title: String(localized: "Couldn’t Move \(url.lastPathComponent) to Trash"),
                    message: error.localizedDescription,
                    symbol: "trash", tone: .danger)
            }
        }
    }
}
