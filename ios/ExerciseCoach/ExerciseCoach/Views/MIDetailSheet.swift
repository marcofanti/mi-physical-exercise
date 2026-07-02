import SwiftUI

/// Detail sheet behind the MI state chips — the full port of the Streamlit
/// sidebar (exercise_app.py:345-379): stage + description, strategy,
/// confidence, current path, rationale, and the highlighted decision tree.
struct MIDetailSheet: View {
    let meta: TurnResult
    let turnCount: Int

    var body: some View {
        NavigationStack {
            List {
                Section("Readiness Stage") {
                    HStack {
                        Circle()
                            .fill(meta.stage.tint)
                            .frame(width: 10, height: 10)
                        Text(meta.stage.rawValue)
                            .fontWeight(.semibold)
                    }
                    Text(meta.stage.descriptionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("MI Strategy") {
                    Text(meta.strategy.rawValue)
                    if let confidence = meta.confidence {
                        Text("Classification confidence: \(confidence, format: .number.precision(.fractionLength(2)))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Turns: \(turnCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Current Path") {
                    Text(meta.barrierPath.joined(separator: " > "))
                        .font(.subheadline)
                }

                Section("Why this node?") {
                    Text(meta.rationale)
                        .font(.subheadline)
                }

                Section("Decision Tree") {
                    DecisionTreeView(selectedPath: meta.barrierPath)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle("Session Focus")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MIDetailSheet(
        meta: TurnResult(
            stage: .contemplation,
            barrierPath: ["Root", "Sense of Capability in Fitness", "Physical discomfort", "Fatigue"],
            strategy: .reflect,
            rationale: "Client repeatedly mentions exhaustion after work.",
            counselorResponse: "",
            confidence: 0.82,
            error: nil
        ),
        turnCount: 3
    )
}
