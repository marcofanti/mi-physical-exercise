@preconcurrency import AVFoundation
import Observation
import Speech

/// On-device streaming speech-to-text using the iOS 26 SpeechAnalyzer +
/// SpeechTranscriber stack. Volatile results stream into `transcript` while
/// the user speaks; `stop()` finalizes and returns the full utterance.
@MainActor
@Observable
final class SpeechInput {
    enum SpeechInputError: Error {
        case localeNotSupported
        case microphoneDenied
    }

    /// Live transcript: finalized text plus the current volatile hypothesis.
    private(set) var transcript = ""
    /// Timestamp of the last transcript change — used for silence detection.
    private(set) var lastTranscriptChange = Date.distantPast
    private(set) var isListening = false

    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var analyzer: SpeechAnalyzer?
    @ObservationIgnored private var transcriber: SpeechTranscriber?
    @ObservationIgnored private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    @ObservationIgnored private var resultsTask: Task<Void, Never>?
    @ObservationIgnored private var finalizedText = ""

    // MARK: - Permissions

    func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Lifecycle

    func start() async throws {
        guard !isListening else { return }

        guard await requestMicrophonePermission() else {
            throw SpeechInputError.microphoneDenied
        }

        transcript = ""
        finalizedText = ""

        let locale = Locale.current
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        self.transcriber = transcriber

        try await ensureModelInstalled(for: transcriber, locale: locale)

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer

        let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber]
        )

        let (inputSequence, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        inputContinuation = continuation

        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    let isFinal = result.isFinal
                    self?.ingest(text: text, isFinal: isFinal)
                }
            } catch {
                // Stream ended or transcription failed; stop() handles cleanup.
            }
        }

        try startAudioEngine(targetFormat: analyzerFormat, continuation: continuation)
        try await analyzer.start(inputSequence: inputSequence)
        isListening = true
    }

    /// Stops listening, finalizes the utterance, and returns the transcript.
    @discardableResult
    func stop() async -> String {
        guard isListening else { return transcript }
        isListening = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        inputContinuation?.finish()
        inputContinuation = nil

        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        resultsTask?.cancel()
        resultsTask = nil
        analyzer = nil
        transcriber = nil

        return transcript
    }

    // MARK: - Private

    private func ingest(text: String, isFinal: Bool) {
        if isFinal {
            finalizedText += text
            transcript = finalizedText
        } else {
            transcript = finalizedText + text
        }
        lastTranscriptChange = .now
    }

    /// Downloads the on-device transcription model if this locale needs it.
    private func ensureModelInstalled(
        for transcriber: SpeechTranscriber,
        locale: Locale
    ) async throws {
        let supported = await SpeechTranscriber.supportedLocales
        guard supported.contains(where: {
            $0.identifier(.bcp47) == locale.identifier(.bcp47)
        }) else {
            throw SpeechInputError.localeNotSupported
        }

        let installed = await SpeechTranscriber.installedLocales
        let isInstalled = installed.contains(where: {
            $0.identifier(.bcp47) == locale.identifier(.bcp47)
        })
        if !isInstalled,
           let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }

    private func startAudioEngine(
        targetFormat: AVAudioFormat?,
        continuation: AsyncStream<AnalyzerInput>.Continuation
    ) throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let converter: AVAudioConverter? = targetFormat.flatMap {
            $0 == inputFormat ? nil : AVAudioConverter(from: inputFormat, to: $0)
        }
        let format = targetFormat

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            guard let converter, let format else {
                continuation.yield(AnalyzerInput(buffer: buffer))
                return
            }
            let ratio = format.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
            guard let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
                return
            }
            var error: NSError?
            nonisolated(unsafe) var consumed = false
            converter.convert(to: converted, error: &error) { _, outStatus in
                if consumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                consumed = true
                outStatus.pointee = .haveData
                return buffer
            }
            if error == nil, converted.frameLength > 0 {
                continuation.yield(AnalyzerInput(buffer: converted))
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }
}
