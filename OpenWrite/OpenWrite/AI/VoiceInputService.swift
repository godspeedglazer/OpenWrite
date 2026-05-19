import AVFoundation
import Combine
import Speech

/// Dictation / talk-to-type for vault chat (macOS Speech framework).
@MainActor
final class VoiceInputService: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var isAvailable = false
    @Published private(set) var statusMessage: String?

    private let speechRecognizer = SFSpeechRecognizer(locale: .current)
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var draftPrefix = ""
    private var onDraftUpdate: ((String) -> Void)?

    init() {
        Task { await refreshAvailability() }
    }

    func refreshAvailability() async {
        let status = SFSpeechRecognizer.authorizationStatus()
        updateAvailability(for: status)
    }

    func toggleListening(currentDraft: String, updateDraft: @escaping (String) -> Void) {
        if isListening {
            stopListening()
            return
        }
        Task {
            await requestAuthorizationIfNeeded()
            guard isAvailable else { return }
            startListening(currentDraft: currentDraft, updateDraft: updateDraft)
        }
    }

    private func requestAuthorizationIfNeeded() async {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            updateAvailability(for: .authorized)
        case .denied, .restricted:
            updateAvailability(for: status)
        case .notDetermined:
            let newStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            updateAvailability(for: newStatus)
        @unknown default:
            updateAvailability(for: status)
        }
    }

    private func startListening(currentDraft: String, updateDraft: @escaping (String) -> Void) {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            statusMessage = "Speech recognition is unavailable for your locale."
            isAvailable = false
            return
        }
        stopListening()

        onDraftUpdate = updateDraft
        draftPrefix = currentDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                    let combined: String
                    if self.draftPrefix.isEmpty {
                        combined = transcript
                    } else if transcript.isEmpty {
                        combined = self.draftPrefix
                    } else {
                        combined = self.draftPrefix + " " + transcript
                    }
                    self.onDraftUpdate?(combined)
                    if result.isFinal {
                        self.stopListening()
                    }
                }
                if error != nil {
                    self.statusMessage = "Voice input ended."
                    self.stopListening()
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            statusMessage = "Listening…"
        } catch {
            statusMessage = "Could not start microphone: \(error.localizedDescription)"
            stopListening()
        }
    }

    func stopListening() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        isListening = false
        onDraftUpdate = nil
        if isAvailable {
            statusMessage = nil
        }
    }

    private func updateAvailability(for status: SFSpeechRecognizerAuthorizationStatus) {
        switch status {
        case .authorized:
            isAvailable = speechRecognizer?.isAvailable ?? false
            statusMessage = isAvailable
                ? nil
                : "Speech recognition is unavailable for your locale."
        case .denied:
            isAvailable = false
            statusMessage = "Allow Speech Recognition for OpenWrite in System Settings → Privacy."
        case .restricted:
            isAvailable = false
            statusMessage = "Speech recognition is restricted on this Mac."
        case .notDetermined:
            isAvailable = false
            statusMessage = "Voice input needs Speech Recognition permission."
        @unknown default:
            isAvailable = false
            statusMessage = "Speech recognition status unknown."
        }
    }
}
