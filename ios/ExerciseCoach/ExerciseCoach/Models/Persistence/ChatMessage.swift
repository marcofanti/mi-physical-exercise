import Foundation
import SwiftData

/// One persisted chat message. Counselor messages carry the turn's inferred
/// MI metadata.
@Model
final class ChatMessage {
    var roleRaw: String
    var text: String
    var timestamp: Date
    var session: ChatSession?

    @Relationship(deleteRule: .cascade)
    var metadata: TurnMetadata?

    init(role: TranscriptMessage.Role, text: String, timestamp: Date = .now) {
        self.roleRaw = role.rawValue
        self.text = text
        self.timestamp = timestamp
    }

    var role: TranscriptMessage.Role {
        TranscriptMessage.Role(rawValue: roleRaw) ?? .assistant
    }

    var asTranscriptMessage: TranscriptMessage {
        TranscriptMessage(role: role, content: text, timestamp: timestamp)
    }
}
