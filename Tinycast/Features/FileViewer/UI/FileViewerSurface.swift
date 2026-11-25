import AppKit

/// What the panel hosts: one file, drawn, and what the panel's zoom chords do to it.
@MainActor
protocol FileViewerSurface: NSView {
    func zoomIn()
    func zoomOut()
    func zoomToActualSize()
    func zoomToFit()
    /// The last call, once the surface is off screen.
    func close()
}
