import AVFoundation
import Observation

/// Spoken counselor replies via AVSpeechSynthesizer. Picks the highest-quality
/// installed voice for the user's locale (premium > enhanced > default).
@MainActor
@Observable
final class SpeechOutput: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var isSpeaking = false

    /// Called on the main actor when an utterance finishes or is cancelled.
    /// Drives the hands-free loop back into listening.
    var onFinish: (@MainActor () -> Void)?

    @ObservationIgnored
    private let synthesizer = AVSpeechSynthesizer()

    @ObservationIgnored
    private lazy var voice: AVSpeechSynthesisVoice? = Self.bestVoice()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        guard !text.isEmpty else {
            onFinish?()
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    private static func bestVoice() -> AVSpeechSynthesisVoice? {
        let languageCode = AVSpeechSynthesisVoice.currentLanguageCode()
        let candidates = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(String(languageCode.prefix(2))) }

        let ranked = candidates.sorted { lhs, rhs in
            qualityRank(lhs.quality) > qualityRank(rhs.quality)
        }
        return ranked.first { $0.language == languageCode } ?? ranked.first
    }

    private static func qualityRank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium: 2
        case .enhanced: 1
        default: 0
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
            self.onFinish?()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
            self.onFinish?()
        }
    }
}
