import Foundation

/// Speech-to-text for chat and capture (v1: protocol + no-op; v1.1+: `Speech` framework).
///
/// Planned implementation on macOS 14+:
/// - `SFSpeechRecognizer` + `SFSpeechAudioBufferRecognitionRequest`
/// - `AVAudioEngine` input tap, `NSSpeechRecognitionUsageDescription` in Info.plist
/// - Partial results on `onPartial`, final transcript on `onFinal`; `stop()` ends capture
///
/// OpenWrite does not link Speech.framework in v1 to keep sandbox and entitlement scope minimal.
protocol DictationService: AnyObject, Sendable {
    var isListening: Bool { get }

    func start(
        onPartial: @escaping @Sendable (String) -> Void,
        onFinal: @escaping @Sendable (String) -> Void
    ) throws

    func stop()
}

/// v1 stub: UI can bind to dictation controls without microphone permission.
final class NoOpDictationService: DictationService, @unchecked Sendable {
    private(set) var isListening = false

    func start(
        onPartial: @escaping @Sendable (String) -> Void,
        onFinal: @escaping @Sendable (String) -> Void
    ) throws {
        isListening = true
        onPartial("")
        onFinal("")
        isListening = false
    }

    func stop() {
        isListening = false
    }
}
