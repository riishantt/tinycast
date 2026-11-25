import AppKit

/// What the panel hosts: one file, drawn, and what the panel's zoom chords do to it.
@MainActor
protocol FileViewerSurface: NSView {
    /// Whether a bare key may be typed into it, which leaves Space and the bare zoom keys alone.
    var takesTyping: Bool { get }
    func zoomIn()
    func zoomOut()
    func zoomToActualSize()
    func zoomToFit()
    /// The last call, once the surface is off screen.
    func close()
}

extension FileViewerSurface {
    var takesTyping: Bool { false }
}
