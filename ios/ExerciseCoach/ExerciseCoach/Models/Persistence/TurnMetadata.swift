import Foundation
import SwiftData

/// Per-turn MI metadata (the Swift equivalent of `exercise_meta` in the
/// Streamlit session state). Stores only the barrier LEAF label — the full
/// canonical path is recomputed from `DecisionTree`, so persisted rows stay
/// valid even if intermediate node labels are ever corrected.
@Model
final class TurnMetadata {
    var stageRaw: String
    var barrierLeaf: String
    var strategyRaw: String
    var rationale: String
    var confidence: Double?
    var createdAt: Date

    init(result: TurnResult, createdAt: Date = .now) {
        self.stageRaw = result.stage.rawValue
        self.barrierLeaf = result.barrierLeaf
        self.strategyRaw = result.strategy.rawValue
        self.rationale = result.rationale
        self.confidence = result.confidence
        self.createdAt = createdAt
    }

    var asTurnResult: TurnResult {
        TurnResult(
            stage: Stage(sanitizing: stageRaw),
            barrierPath: DecisionTree.path(to: barrierLeaf) ?? [DecisionTree.rootLabel],
            strategy: Strategy(sanitizing: strategyRaw),
            rationale: rationale,
            counselorResponse: "",
            confidence: confidence,
            error: nil
        )
    }
}
