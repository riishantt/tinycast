import SwiftUI

/// The palette's glass behind the photo, so the letterbox around it reads as Tinycast.
struct ImageViewerView: View {
    let canvas: ImageViewerCanvas

    var body: some View {
        CanvasHost(canvas: canvas)
            .background(Theme.Colors.panelScrim)
            .background(GlassEffectView())
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}

/// The coordinator keeps the canvas, so the panel's commands reach the one on screen.
private struct CanvasHost: NSViewRepresentable {
    let canvas: ImageViewerCanvas

    func makeNSView(context: Context) -> ImageViewerCanvas {
        canvas
    }

    func updateNSView(_ canvas: ImageViewerCanvas, context: Context) {}
}
