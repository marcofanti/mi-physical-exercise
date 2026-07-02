import Foundation
import SwiftData

/// One counseling conversation, persisted on device.
@Model
final class ChatSession {
    var startedAt: Date
    /// First user message, truncated — shown in the history list.
    var title: String
    var turnCount: Int
    /// Raw value of the last inferred stage, for the history list chip.
    var lastStageRaw: String

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage]

    @Relationship(deleteRule: .cascade, inverse: \CommittedStep.session)
    var committedSteps: [CommittedStep]

    init(startedAt: Date = .now) {
        self.startedAt = startedAt
        self.title = ""
        self.turnCount = 0
        self.lastStageRaw = Stage.contemplation.rawValue
        self.messages = []
        self.committedSteps = []
    }

    var sortedMessages: [ChatMessage] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    var lastStage: Stage { Stage(sanitizing: lastStageRaw) }
}
