import AVFoundation
import Observation

/// Hands-free conversation state machine:
/// idle → listening → thinking → speaking → listening → …
///
/// End-of-utterance is detected by transcript silence (~1.5 s with text
/// present). No barge-in: the mic is stopped while the counselor speaks;
/// tapping the mic while speaking cuts the reply and resumes listening.
@MainActor
@Observable
final class VoiceConversationController {
    enum VoiceState: Equatable {
        case idle
        case listening
        case thinking
        case speaking
    }

    private(set) var state: VoiceState = .idle
    private(set) var errorMessage: String?

    var isActive: Bool { state != .idle }
    var liveTranscript: String { speechInput.transcript }

    let speechInput: SpeechInput
    let speechOutput: SpeechOutput

    /// Sends one user utterance through the counselor and returns the reply.
    private let sendUtterance: @MainActor (String) async -> String

    @ObservationIgnored private var silenceTask: Task<Void, Never>?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?

    private static let silenceThreshold: TimeInterval = 1.5

    init(
        speechInput: SpeechInput = SpeechInput(),
        speechOutput: SpeechOutput = SpeechOutput(),
        sendUtterance: @escaping @MainActor (String) async -> String
    ) {
        self.speechInput = speechInput
        self.speechOutput = speechOutput
        self.sendUtterance = sendUtterance

        speechOutput.onFinish = { [weak self] in
            self?.resumeListeningAfterSpeech()
        }
        observeAudioInterruptions()
    }

    // MARK: - Controls

    func toggle() {
        switch state {
        case .idle:
            start()
        case .speaking:
            // Mic tap while speaking: cut the reply; onFinish resumes listening.
            speechOutput.stop()
        default:
            stop()
        }
    }

    func start() {
        guard state == .idle else { return }
        errorMessage = nil
        Task { await beginListening() }
    }

    func stop() {
        silenceTask?.cancel()
        silenceTask = nil
        speechOutput.stop()
        Task { await speechInput.stop() }
        state = .idle
        deactivateAudioSession()
    }

    // MARK: - Loop

    private func beginListening() async {
        do {
            try configureAudioSession()
            try await speechInput.start()
            state = .listening
            watchForSilence()
        } catch {
            errorMessage = "Couldn't start listening. Check microphone access in Settings."
            state = .idle
        }
    }

    private func watchForSilence() {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, self.state == .listening else { return }

                let transcript = self.speechInput.transcript
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let sinceChange = Date.now.timeIntervalSince(self.speechInput.lastTranscriptChange)

                if !transcript.isEmpty, sinceChange > Self.silenceThreshold {
                    await self.finishUtterance()
                    return
                }
            }
        }
    }

    private func finishUtterance() async {
        silenceTask?.cancel()
        silenceTask = nil

        let utterance = await speechInput.stop()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !utterance.isEmpty, state == .listening else {
            if state == .listening { await beginListening() }
            return
        }

        state = .thinking
        let reply = await sendUtterance(utterance)

        guard state == .thinking else { return } // user ended voice mode mid-turn
        state = .speaking
        speechOutput.speak(reply)
    }

    private func resumeListeningAfterSpeech() {
        guard state == .speaking else { return }
        Task { await beginListening() }
    }

    // MARK: - Audio session

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.duckOthers, .allowBluetoothHFP, .defaultToSpeaker]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    /// Calls, Siri, etc. pause the loop entirely — the user restarts manually.
    private func observeAudioInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isActive else { return }
                self.stop()
                self.errorMessage = "Voice paused by an interruption. Tap the mic to resume."
            }
        }
    }
}
