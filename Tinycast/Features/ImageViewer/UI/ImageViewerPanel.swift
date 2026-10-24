import AppKit
import Carbon.HIToolbox

/// The viewer's panel; keys go through `sendEvent`, so no subview has to hold focus for them.
final class ImageViewerPanel: NSPanel, AnimatedPanel {
    enum Command {
        case close
        case zoomIn
        case zoomOut
        case actualSize
        case fit
        case trash
    }

    var onCommand: ((Command) -> Void)?

    init(content: NSView) {
        super.init(
            contentRect: NSRect(origin: .zero, size: content.frame.size),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        followMotion()
        isReleasedWhenClosed = false
        isRestorable = false
        contentView = content
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown, let onCommand, let command = Self.command(for: event) else {
            super.sendEvent(event)
            return
        }
        onCommand(command)
    }

    /// As the palette does: a click on another app or the desktop takes key, and that closes it.
    override func resignKey() {
        super.resignKey()
        onCommand?(.close)
    }

    /// Preview's chords, plus Quick Look's Space to close; zoom also takes a bare `=` and `-`.
    private static func command(for event: NSEvent) -> Command? {
        let isCommand = event.modifierFlags.contains(.command)
        switch Int(event.keyCode) {
        case kVK_Escape, kVK_Space: return .close
        case kVK_Delete where isCommand: return .trash
        default: break
        }
        switch event.charactersIgnoringModifiers {
        case "w" where isCommand: return .close
        case "=", "+": return .zoomIn
        case "-": return .zoomOut
        case "0" where isCommand: return .actualSize
        case "9" where isCommand: return .fit
        default: return nil
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
