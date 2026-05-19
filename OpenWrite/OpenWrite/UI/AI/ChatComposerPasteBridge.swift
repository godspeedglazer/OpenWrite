import AppKit
import SwiftUI

/// Intercepts ⌘V image paste for the chat composer when SwiftUI `onPasteCommand` does not reach `TextField`.
struct ChatComposerPasteBridge: NSViewRepresentable {
    var isActive: Bool
    var onPasteImage: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPasteImage: onPasteImage)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onPasteImage = onPasteImage
        context.coordinator.isActive = isActive
        if isActive {
            context.coordinator.startMonitoring()
        } else {
            context.coordinator.stopMonitoring()
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    final class Coordinator {
        var onPasteImage: () -> Void
        var isActive = false
        private var monitor: Any?

        init(onPasteImage: @escaping () -> Void) {
            self.onPasteImage = onPasteImage
        }

        func startMonitoring() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isActive,
                      event.modifierFlags.contains(.command),
                      event.charactersIgnoringModifiers?.lowercased() == "v",
                      ImagePasteSupport.pasteboardHasIngestibleImage else {
                    return event
                }
                let responder = NSApp.keyWindow?.firstResponder
                if Self.shouldDeferPasteToBlockEditor(responder) {
                    return event
                }
                self.onPasteImage()
                return nil
            }
        }

        func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        /// Block editor uses `NSTextView`; chat composer uses SwiftUI `TextField` (`NSTextField`).
        private static func shouldDeferPasteToBlockEditor(_ responder: NSResponder?) -> Bool {
            responder is NSTextView
        }
    }
}
