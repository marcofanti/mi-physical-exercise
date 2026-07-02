import Testing
@testable import ExerciseCoach

struct PromptBuilderTests {
    /// The 6-message window with Counselor/Client labels — pinned by running
    /// Python `recent_chat_for_prompt` (exercise_app.py:177-182) on the same
    /// 7-message chat (the oldest message must be dropped).
    @Test func recentChatWindowMatchesPython() {
        let chat: [TranscriptMessage] = [
            .init(role: .assistant, content: "Hi. What has exercise been like for you lately?"),
            .init(role: .user, content: "Not great."),
            .init(role: .assistant, content: "Say more?"),
            .init(role: .user, content: "Busy with school."),
            .init(role: .assistant, content: "That sounds full."),
            .init(role: .user, content: "Yeah."),
            .init(role: .assistant, content: "What would help?"),
        ]
        let expected = "Client: Not great.\nCounselor: Say more?\nClient: Busy with school.\nCounselor: That sounds full.\nClient: Yeah.\nCounselor: What would help?"
        #expect(PromptBuilder.recentChat(chat) == expected)
    }

    /// Without health context the turn prompt is byte-identical to the Python
    /// f-string user_prompt (exercise_app.py:215-220), trailing newline included.
    @Test func turnPromptMatchesPythonFormat() {
        let chat: [TranscriptMessage] = [
            .init(role: .assistant, content: "Hi."),
            .init(role: .user, content: "Hello."),
        ]
        let expected = "Recent conversation:\nCounselor: Hi.\nClient: Hello.\n\nLatest client message:\nSo busy lately.\n"
        #expect(PromptBuilder.turnPrompt(userText: "So busy lately.", chat: chat) == expected)
    }

    @Test func turnPromptWithHealthContextInsertsOneLine() {
        let chat: [TranscriptMessage] = [.init(role: .assistant, content: "Hi.")]
        let prompt = PromptBuilder.turnPrompt(
            userText: "Tired.",
            chat: chat,
            healthContext: "Client activity this week: avg 4,200 steps/day."
        )
        let expected = "Recent conversation:\nCounselor: Hi.\n\nClient activity this week: avg 4,200 steps/day.\n\nLatest client message:\nTired.\n"
        #expect(prompt == expected)
    }

    /// Instructions embed the pinned leaf-path text and the exact Python list
    /// reprs, and keep the two behavioral rules verbatim.
    @Test func instructionsContainPortedBlocks() {
        let instructions = PromptBuilder.instructions
        #expect(instructions.hasPrefix("You are a Motivational Interviewing counselor for physical exercise.\nUse the V8 exercise-barrier decision tree as the functional map of the conversation."))
        #expect(instructions.contains(DecisionTree.leafPathText))
        #expect(instructions.contains("1. infer the client's readiness stage: one of ['Precontemplation', 'Contemplation', 'Preparation']"))
        #expect(instructions.contains("3. choose one MI strategy from ['Reflect', 'Open Question', 'Affirm', 'Emphasize Control', 'Reframe', 'Support', 'Advise with Permission']"))
        #expect(instructions.contains("4. write one counselor response under 80 words"))
        #expect(instructions.contains("Do not mention motivational interviewing, stages, strategies, or the tree to the client.\nAvoid giving a plan unless the client sounds ready or you ask permission first."))
        // Guided generation replaces the Python "Return only JSON" tail.
        #expect(!instructions.contains("Return only JSON"))
    }
}
