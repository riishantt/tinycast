import AppKit
import SwiftUI

/// Owns the file viewer: one panel at a time, for the file Finder or Search Files handed over.
@MainActor
final class FileViewerCoordinator {
    private unowned let core: AppCore
    private var panel: FileViewerPanel?
    private var surface: (any FileViewerSurface)?
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
            let content = await FileViewerContent.load(url, screenPixels: screenPixels)
            guard let self, !Task.isCancelled else { return }
            loading = nil
            guard let content else {
                reportUnopened(url)
                return
            }
            present(content, of: url, in: visible)
        }
    }

    func close() {
        loading?.cancel()
        loading = nil
        guard let closing = panel else { return }
        let closingSurface = surface
        panel = nil
        surface = nil
        shown = nil
        closing.onCommand = nil
        closing.orderOutAnimated { closingSurface?.close() }
    }

    private func present(_ content: FileViewerContent, of url: URL, in visible: CGRect) {
        let (next, size) = makeSurface(for: content, of: url, visible: visible.size)
        let frame = CGRect(
            x: (visible.midX - size.width / 2).rounded(),
            y: (visible.midY - size.height / 2).rounded(),
            width: size.width, height: size.height)
        let panel = panel ?? makePanel()
        let replaced = surface
        panel.setFrame(frame, display: false)
        let hosting = NSHostingView(rootView: FileViewerView(surface: next))
        hosting.sizingOptions = []
        panel.contentView = hosting
        panel.takesTyping = next.takesTyping
        replaced?.close()
        surface = next
        shown = url
        // Non-activating like the palette: key focus without pulling the user out of Finder.
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func makeSurface(
        for content: FileViewerContent, of url: URL, visible: CGSize
    ) -> (any FileViewerSurface, CGSize) {
        let name = url.lastPathComponent
        switch content {
        case .photo(let photo):
            let size = ImageViewerFitPolicy.windowSize(image: photo.size, visible: visible)
            let canvas = ImageViewerCanvas()
            canvas.show(photo, named: name, in: size)
            return (canvas, size)
        case .pdf(let shape, let isLocked):
            let size = shape.windowSize(visible: visible)
            return (FileViewerPDFSurface(url: url, isLocked: isLocked, size: size), size)
        case .text(let text):
            let size = FileViewerDocumentShape.page.windowSize(visible: visible)
            return (FileViewerTextSurface(text: text, named: name, size: size), size)
        case .document(let shape):
            let size = shape.windowSize(visible: visible)
            return (FileViewerDocumentSurface(url: url, size: size), size)
        }
    }

    private func makePanel() -> FileViewerPanel {
        let panel = FileViewerPanel()
        panel.onCommand = { [weak self] command in self?.perform(command) }
        self.panel = panel
        return panel
    }

    private func perform(_ command: FileViewerPanel.Command) {
        switch command {
        case .close: close()
        case .zoomIn: surface?.zoomIn()
        case .zoomOut: surface?.zoomOut()
        case .actualSize: surface?.zoomToActualSize()
        case .fit: surface?.zoomToFit()
        case .openElsewhere: openElsewhere()
        case .trash: trash()
        }
    }

    /// The viewer only reads, so this is the way on to an editor once Tinycast is the default.
    private func openElsewhere() {
        guard let url = shown else { return }
        let app = (surface is FileViewerPDFSurface ? defaultBrowser : nil) ?? otherApp(for: url)
        close()
        guard let app else {
            reportUnopened(url)
            return
        }
        Task {
            do {
                _ = try await NSWorkspace.shared.open(
                    [url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
            } catch {
                reportUnopened(url)
            }
        }
    }

    private var defaultBrowser: URL? {
        URL(string: "https://example.com").flatMap {
            NSWorkspace.shared.urlForApplication(toOpen: $0)
        }
    }

    private func otherApp(for url: URL) -> URL? {
        let own = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.urlsForApplications(toOpen: url)
            .first { Bundle(url: $0)?.bundleIdentifier != own }
    }

    private func reportUnopened(_ url: URL) {
        core.showMessage(String(localized: "Couldn’t Open \(url.lastPathComponent)"), tone: .danger)
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
