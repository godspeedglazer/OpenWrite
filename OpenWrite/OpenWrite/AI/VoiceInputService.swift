import Foundation
import Combine

/// Dictation / talk-to-type hook for vault chat (macOS Speech framework — not wired yet).
@MainActor
final class VoiceInputService: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var isAvailable = false
    @Published private(set) var statusMessage: String?

    init() {
        // TODO: Probe SFSpeechRecognizer authorization and locale support.
        isAvailable = false
        statusMessage = "Enable Speech Recognition in System Settings to use voice input."
    }

    func toggleListening(appendTo draft: inout String) {
        guard isAvailable else {
            statusMessage = "Enable Speech Recognition in System Settings to use voice input."
            return
        }
        if isListening {
            stopListening()
        } else {
            startListening(appendTo: &draft)
        }
    }

    func startListening(appendTo draft: inout String) {
        // TODO: Wire AVAudioEngine + SFSpeechRecognizer; stream partials into `draft`.
        isListening = true
        statusMessage = "Listening…"
        _ = draft
    }

    func stopListening() {
        isListening = false
        statusMessage = isAvailable ? nil : "Enable Speech Recognition in System Settings to use voice input."
    }
}
