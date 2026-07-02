import FoundationModels

/// Guided-generation schema for one counselor turn — the Swift equivalent of
/// the six-key JSON contract in `infer_and_respond` (exercise_app.py:212-213):
/// stage, barrier_path, strategy, rationale, counselor_response, confidence.
///
/// Differences from the Python contract, by design:
/// - `barrierLeaf` is a single leaf name constrained by `.anyOf`, not a free-form
///   path string. Guided generation guarantees a valid tree node, so Python's
///   `normalize_path` repair logic (exercise_app.py:133-146) is unnecessary;
///   Swift maps the leaf to its full canonical path via `DecisionTree.path(to:)`.
/// - Property order is generation order: classify first, respond after.
@Generable
struct CounselorTurn {
    @Guide(
        description: "Client readiness stage",
        .anyOf(Stage.allCases.map(\.rawValue))
    )
    var stage: String

    @Guide(
        description: "Exact name of the one decision-tree leaf barrier that best matches the client, or \"Root\" if none applies",
        .anyOf(DecisionTree.leafLabels + [DecisionTree.rootLabel])
    )
    var barrierLeaf: String

    @Guide(
        description: "Motivational interviewing strategy for this turn",
        .anyOf(Strategy.allCases.map(\.rawValue))
    )
    var strategy: String

    @Guide(description: "One short sentence explaining the stage and barrier classification")
    var rationale: String

    @Guide(description: "Counselor reply to the client, under 80 words")
    var counselorResponse: String

    @Guide(description: "Classification confidence between 0.0 and 1.0")
    var confidence: Double
}
