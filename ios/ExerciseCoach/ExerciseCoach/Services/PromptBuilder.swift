import Foundation

/// Builds the per-turn prompts, ported from `infer_and_respond`
/// (exercise_app.py:198-220).
enum PromptBuilder {
    /// Python renders `{list(STAGES)}` — reproduce the exact repr.
    static let stagesListRepr = "['Precontemplation', 'Contemplation', 'Preparation']"

    /// Python renders `{STRATEGIES}` — reproduce the exact repr.
    static let strategiesListRepr =
        "['Reflect', 'Open Question', 'Affirm', 'Emphasize Control', 'Reframe', 'Support', 'Advise with Permission']"

    /// System prompt, ported from exercise_app.py:198-214 with two deliberate
    /// adaptations for on-device guided generation:
    /// - step 2 asks for "one exact leaf" (the schema constrains `barrierLeaf`
    ///   with .anyOf, so the model picks a node, not a free-form path)
    /// - the trailing "Return only JSON with keys: ..." block is dropped —
    ///   Foundation Models injects the response schema itself.
    /// Everything else is verbatim.
    static let instructions: String = """
        You are a Motivational Interviewing counselor for physical exercise.
        Use the V8 exercise-barrier decision tree as the functional map of the conversation.

        Decision-tree leaf paths:
        \(DecisionTree.leafPathText)

        In one pass:
        1. infer the client's readiness stage: one of \(stagesListRepr)
        2. classify the client's main barrier to one exact leaf from the tree
        3. choose one MI strategy from \(strategiesListRepr)
        4. write one counselor response under 80 words

        Do not mention motivational interviewing, stages, strategies, or the tree to the client.
        Avoid giving a plan unless the client sounds ready or you ask permission first.
        """

    /// Last `limit` messages as "Counselor:/Client:" lines.
    /// Verbatim port of `recent_chat_for_prompt` (exercise_app.py:177-182).
    static func recentChat(_ chat: [TranscriptMessage], limit: Int = 6) -> String {
        chat.suffix(limit)
            .map { message in
                let speaker = message.role == .assistant ? "Counselor" : "Client"
                return "\(speaker): \(message.content)"
            }
            .joined(separator: "\n")
    }

    /// Turn prompt, verbatim port of `user_prompt` (exercise_app.py:215-220),
    /// including the trailing newline of the Python f-string.
    ///
    /// `healthContext` (Phase 4) inserts one extra activity line between the
    /// conversation block and the latest message; when nil the output is
    /// byte-identical to the Python prompt.
    static func turnPrompt(
        userText: String,
        chat: [TranscriptMessage],
        messageLimit: Int = 6,
        healthContext: String? = nil
    ) -> String {
        let healthBlock = healthContext.map { "\($0)\n\n" } ?? ""
        return """
            Recent conversation:
            \(recentChat(chat, limit: messageLimit))

            \(healthBlock)Latest client message:
            \(userText)

            """
    }
}
