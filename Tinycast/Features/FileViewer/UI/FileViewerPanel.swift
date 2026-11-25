import AppKit
import Carbon.HIToolbox

/// The viewer's panel; keys go through `sendEvent`, so no subview has to hold focus for them.
final class FileViewerPanel: NSPanel, AnimatedPanel {
    enum Command {
        case close
        case zoomIn
        case zoomOut
        case actualSize
        case fit
        case openElsewhere
        case trash
    }

    var onCommand: ((Command) -> Void)?
    var takesTyping = false

    init() {
        super.init(
            contentRect: .zero,
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
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown, let onCommand, !isTyping(event),
            let command = Self.command(for: event)
        else {
            super.sendEvent(event)
            return
        }
        onCommand(command)
    }

    private func isTyping(_ event: NSEvent) -> Bool {
        takesTyping && event.keyCode != kVK_Escape && !event.modifierFlags.contains(.command)
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
        case "o" where isCommand: return .openElsewhere
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
