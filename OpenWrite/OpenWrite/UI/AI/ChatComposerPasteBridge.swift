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
                      ImagePasteSupport.shouldIngestImageFromPasteboard else {
                    return event
                }
                let responder = NSApp.keyWindow?.firstResponder
                if Self.shouldDeferPasteToTextResponder(responder) {
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

        /// Let focused text responders handle ⌘V when the pasteboard carries plain text.
        private static func shouldDeferPasteToTextResponder(_ responder: NSResponder?) -> Bool {
            guard ImagePasteSupport.pasteboardHasSubstantivePlainText else { return false }
            return responder is NSTextView || responder is NSTextField
        }
    }
}
