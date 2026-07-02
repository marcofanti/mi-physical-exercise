import Foundation
import SwiftData

/// A small, self-directed next step the user committed to, with an optional
/// scheduled check-in notification. Used from Phase 4 onward.
@Model
final class CommittedStep {
    var text: String
    var createdAt: Date
    var remindAt: Date
    var notificationIdentifier: String
    var isCompleted: Bool
    var session: ChatSession?

    init(text: String, remindAt: Date, notificationIdentifier: String = UUID().uuidString) {
        self.text = text
        self.createdAt = .now
        self.remindAt = remindAt
        self.notificationIdentifier = notificationIdentifier
        self.isCompleted = false
    }
}
