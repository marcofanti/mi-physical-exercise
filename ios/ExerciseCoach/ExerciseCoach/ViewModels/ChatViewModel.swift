import Foundation
import Observation
import SwiftData

/// Drives one counseling conversation — the Swift equivalent of the Streamlit
/// session state + turn handler (exercise_app.py:325-342, 411-426) — and
/// persists it to SwiftData.
@MainActor
@Observable
final class ChatViewModel {
    private(set) var messages: [TranscriptMessage]
    private(set) var meta: TurnResult
    private(set) var turnCount: Int
    private(set) var isThinking = false

    let engine: CounselorEngine
    let healthProvider: HealthContextProvider
    private let context: ModelContext
    /// Created lazily on the first user message so empty sessions never
    /// clutter the history list.
    private var session: ChatSession?

    /// True when the client sounds ready — surfaces the "Commit to a next
    /// step" affordance in the UI.
    var showsCommitAffordance: Bool {
        meta.stage == .preparation && turnCount > 0
    }

    /// Prefill for the commit sheet: the user's own words.
    var lastUserMessage: String {
        messages.last(where: { $0.role == .user })?.content ?? ""
    }

    init(
        context: ModelContext,
        engine: CounselorEngine = CounselorEngine(),
        healthProvider: HealthContextProvider = HealthContextProvider()
    ) {
        self.context = context
        self.engine = engine
        self.healthProvider = healthProvider
        self.messages = [TranscriptMessage(role: .assistant, content: SessionSeed.greeting)]
        self.meta = .initial
        self.turnCount = 0
    }

    /// Refreshes HealthKit grounding (authorization prompt on first call).
    func refreshHealthContext() async {
        await healthProvider.refresh()
    }

    /// Mirrors the Python turn handler: append user message → infer/respond →
    /// store meta → bump turn → append counselor reply. Persists both messages
    /// and the turn's MI metadata.
    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }

        messages.append(TranscriptMessage(role: .user, content: trimmed))
        persistUserMessage(trimmed)

        isThinking = true
        defer { isThinking = false }

        let result = await engine.respond(
            userText: trimmed,
            chat: messages,
            healthContext: healthProvider.summaryLine
        )

        meta = result
        turnCount += 1
        messages.append(TranscriptMessage(role: .assistant, content: result.counselorResponse))
        persistCounselorTurn(result)
    }

    /// Mirrors `reset_session` (exercise_app.py:288-304). The previous session
    /// stays in SwiftData; a new one is created on the next user message.
    func reset() {
        session = nil
        messages = [TranscriptMessage(role: .assistant, content: SessionSeed.greeting)]
        meta = .initial
        turnCount = 0
    }

    /// Starts a fresh session seeded with a check-in greeting after the user
    /// tapped a scheduled notification for a committed step.
    func startCheckIn(stepText: String, completed: Bool) {
        reset()
        let greeting = completed
            ? "Nice — you planned \"\(stepText)\" and did it. What felt good about it?"
            : "Hi. You planned: \"\(stepText)\". How did it go?"
        messages = [TranscriptMessage(role: .assistant, content: greeting)]
    }

    /// Persists a committed next step and schedules its check-in notification.
    /// Returns false if notification permission was denied (the step is still
    /// saved).
    @discardableResult
    func commitStep(text: String, remindAt: Date) async -> Bool {
        let step = CommittedStep(text: text, remindAt: remindAt)
        step.session = session
        context.insert(step)
        save()
        return await NotificationScheduler.scheduleCheckIn(
            text: step.text,
            remindAt: step.remindAt,
            notificationIdentifier: step.notificationIdentifier
        )
    }

    // MARK: - Persistence

    private func ensureSession(firstUserText: String) -> ChatSession {
        if let session { return session }

        let newSession = ChatSession()
        newSession.title = String(firstUserText.prefix(60))
        context.insert(newSession)

        // Backfill the opening message (default or check-in greeting) so
        // stored transcripts read complete.
        let greeting = ChatMessage(
            role: .assistant,
            text: messages.first?.content ?? SessionSeed.greeting,
            timestamp: newSession.startedAt
        )
        greeting.session = newSession
        context.insert(greeting)

        session = newSession
        return newSession
    }

    private func persistUserMessage(_ text: String) {
        let session = ensureSession(firstUserText: text)
        let message = ChatMessage(role: .user, text: text)
        message.session = session
        context.insert(message)
        save()
    }

    private func persistCounselorTurn(_ result: TurnResult) {
        guard let session else { return }
        let message = ChatMessage(role: .assistant, text: result.counselorResponse)
        message.session = session
        message.metadata = TurnMetadata(result: result)
        context.insert(message)

        session.turnCount = turnCount
        session.lastStageRaw = result.stage.rawValue
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            // Persistence must never break the conversation; the in-memory
            // transcript remains the source of truth for the current session.
            assertionFailure("SwiftData save failed: \(error)")
        }
    }
}
