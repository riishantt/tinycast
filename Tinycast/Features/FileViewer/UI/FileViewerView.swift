import SwiftUI

/// The palette's glass behind the file, so whatever it leaves bare reads as Tinycast.
struct FileViewerView: View {
    let surface: any FileViewerSurface

    var body: some View {
        SurfaceHost(surface: surface)
            .background(GlassEffectView())
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}

/// The coordinator keeps the surface, so the panel's commands reach the one on screen.
private struct SurfaceHost: NSViewRepresentable {
    let surface: any FileViewerSurface

    func makeNSView(context: Context) -> NSView {
        surface
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
