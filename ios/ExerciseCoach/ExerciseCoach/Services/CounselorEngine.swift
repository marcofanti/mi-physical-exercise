import Foundation
import FoundationModels

/// On-device counselor brain — the Swift equivalent of `infer_and_respond`
/// (exercise_app.py:185-273), backed by Apple's Foundation Models framework.
///
/// Architecture mirrors the Python app: stateless per turn. Every turn uses a
/// fresh `LanguageModelSession` whose instructions embed the decision tree,
/// prompted with only the last 6 messages. This keeps each request far below
/// the on-device context window and avoids transcript accumulation.
@MainActor
@Observable
final class CounselorEngine {
    /// Session prewarmed for the next turn (instructions are constant, so
    /// prewarming is effective for latency).
    @ObservationIgnored
    private var nextSession: LanguageModelSession?

    var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    init() {
        prewarmNextTurn()
    }

    // MARK: - Turn pipeline

    /// One counselor turn. Never throws and never surfaces a raw error as the
    /// counselor reply — all failures degrade through the keyword classifier
    /// and templated responses, matching the Python fallback path.
    func respond(
        userText: String,
        chat: [TranscriptMessage],
        healthContext: String? = nil
    ) async -> TurnResult {
        let session = nextSession ?? makeSession()
        nextSession = nil
        defer { prewarmNextTurn() }

        do {
            let turn = try await generate(
                session: session,
                userText: userText,
                chat: chat,
                messageLimit: 6,
                healthContext: healthContext
            )
            return sanitized(turn, userText: userText)
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                // Retry once with a smaller window on a fresh session,
                // mirroring the plan's context guard.
                if let retry = try? await generate(
                    session: makeSession(),
                    userText: userText,
                    chat: chat,
                    messageLimit: 3,
                    healthContext: nil
                ) {
                    return sanitized(retry, userText: userText)
                }
            }
            return fallbackResult(userText: userText, error: String(describing: error))
        } catch {
            return fallbackResult(userText: userText, error: String(describing: error))
        }
    }

    private func generate(
        session: LanguageModelSession,
        userText: String,
        chat: [TranscriptMessage],
        messageLimit: Int,
        healthContext: String?
    ) async throws -> CounselorTurn {
        let prompt = PromptBuilder.turnPrompt(
            userText: userText,
            chat: chat,
            messageLimit: messageLimit,
            healthContext: healthContext
        )
        let response = try await session.respond(
            to: prompt,
            generating: CounselorTurn.self,
            options: GenerationOptions(temperature: 0.2)
        )
        return response.content
    }

    // MARK: - Sanitization (ports exercise_app.py:246-273)

    private func sanitized(_ turn: CounselorTurn, userText: String) -> TurnResult {
        let stage = Stage(sanitizing: turn.stage)
        let strategy = Strategy(sanitizing: turn.strategy)

        // Guided generation guarantees barrierLeaf ∈ leaves + Root, but map
        // defensively: unknown labels fall back to keyword classification,
        // like normalize_path (exercise_app.py:133-146).
        let barrierPath = DecisionTree.path(to: turn.barrierLeaf)
            ?? FallbackClassifier.classify(userText)

        var response = turn.counselorResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        if response.isEmpty {
            response = Self.templatedResponse(for: barrierPath)
        }

        var rationale = turn.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        if rationale.isEmpty {
            rationale = "Fallback or concise model classification."
        }

        return TurnResult(
            stage: stage,
            barrierPath: barrierPath,
            strategy: strategy,
            rationale: rationale,
            counselorResponse: response,
            confidence: min(max(turn.confidence, 0), 1),
            error: nil
        )
    }

    /// Full fallback when the model call fails: keyword classification plus
    /// sanitizer defaults (Contemplation / Reflect) and a templated reply.
    func fallbackResult(userText: String, error: String?) -> TurnResult {
        let barrierPath = FallbackClassifier.classify(userText)
        return TurnResult(
            stage: .contemplation,
            barrierPath: barrierPath,
            strategy: .reflect,
            rationale: "Fallback or concise model classification.",
            counselorResponse: Self.templatedResponse(for: barrierPath),
            confidence: nil,
            error: error
        )
    }

    /// Templated replies, ported verbatim from exercise_app.py:253-263.
    nonisolated static func templatedResponse(for barrierPath: [String]) -> String {
        if barrierPath == [DecisionTree.rootLabel] {
            return "That sounds like things may be going okay right now. "
                + "What would you like exercise to look like for you?"
        }
        let leaf = barrierPath.last ?? "exercise"
        return "It sounds like \(leaf.lowercased()) is getting in the way. "
            + "What feels most workable to change, even a little, this week?"
    }

    // MARK: - Session management

    private func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: PromptBuilder.instructions)
    }

    private func prewarmNextTurn() {
        guard isAvailable else { return }
        let session = makeSession()
        session.prewarm()
        nextSession = session
    }
}
