import Foundation

/// Client readiness stage from the Transtheoretical Model.
/// Raw values and descriptions are ported verbatim from `STAGES`
/// (exercise_app.py:31-35).
enum Stage: String, CaseIterable, Codable, Sendable {
    case precontemplation = "Precontemplation"
    case contemplation = "Contemplation"
    case preparation = "Preparation"

    var descriptionText: String {
        switch self {
        case .precontemplation:
            "Not yet seeing exercise change as important."
        case .contemplation:
            "Interested or ambivalent, but not ready for a concrete plan."
        case .preparation:
            "Ready to try a specific next step."
        }
    }

    /// Mirrors `sanitize_stage` (exercise_app.py:167-169): unknown → Contemplation.
    init(sanitizing raw: String?) {
        self = Stage(rawValue: (raw ?? "").trimmingCharacters(in: .whitespaces)) ?? .contemplation
    }
}

/// Motivational-interviewing strategies, ported verbatim from `STRATEGIES`
/// (exercise_app.py:37-45).
enum Strategy: String, CaseIterable, Codable, Sendable {
    case reflect = "Reflect"
    case openQuestion = "Open Question"
    case affirm = "Affirm"
    case emphasizeControl = "Emphasize Control"
    case reframe = "Reframe"
    case support = "Support"
    case adviseWithPermission = "Advise with Permission"

    /// Mirrors `sanitize_strategy` (exercise_app.py:172-174): unknown → Reflect.
    init(sanitizing raw: String?) {
        self = Strategy(rawValue: (raw ?? "").trimmingCharacters(in: .whitespaces)) ?? .reflect
    }
}

/// One message in the conversation transcript.
struct TranscriptMessage: Identifiable, Hashable, Sendable {
    enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// Structured result of one counselor turn — the Swift equivalent of the
/// dict returned by `infer_and_respond` (exercise_app.py:265-273).
struct TurnResult: Sendable, Equatable {
    var stage: Stage
    var barrierPath: [String]
    var strategy: Strategy
    var rationale: String
    var counselorResponse: String
    var confidence: Double?
    var error: String?

    /// Initial sidebar meta, ported from `reset_session` (exercise_app.py:297-303).
    static let initial = TurnResult(
        stage: .contemplation,
        barrierPath: [DecisionTree.rootLabel],
        strategy: .openQuestion,
        rationale: "Session initialized.",
        counselorResponse: "",
        confidence: nil,
        error: nil
    )

    var barrierLeaf: String { barrierPath.last ?? DecisionTree.rootLabel }
}

/// Opening counselor greeting, ported from `reset_session` (exercise_app.py:291-293).
enum SessionSeed {
    static let greeting = "Hi. What has exercise been like for you lately?"
}
