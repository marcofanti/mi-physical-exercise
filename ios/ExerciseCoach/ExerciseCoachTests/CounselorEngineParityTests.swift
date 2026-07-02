import Testing
@testable import ExerciseCoach

struct CounselorEngineParityTests {
    // MARK: - Sanitizers (exercise_app.py:167-174)

    @Test func stageSanitizerDefaultsToContemplation() {
        #expect(Stage(sanitizing: "Precontemplation") == .precontemplation)
        #expect(Stage(sanitizing: " Preparation ") == .preparation)
        #expect(Stage(sanitizing: "Maintenance") == .contemplation)
        #expect(Stage(sanitizing: "") == .contemplation)
        #expect(Stage(sanitizing: nil) == .contemplation)
    }

    @Test func strategySanitizerDefaultsToReflect() {
        #expect(Strategy(sanitizing: "Open Question") == .openQuestion)
        #expect(Strategy(sanitizing: "Advise with Permission") == .adviseWithPermission)
        #expect(Strategy(sanitizing: "Lecture") == .reflect)
        #expect(Strategy(sanitizing: nil) == .reflect)
    }

    // MARK: - Templated responses (exercise_app.py:253-263)

    @Test func rootTemplatedResponse() {
        #expect(CounselorEngine.templatedResponse(for: ["Root"])
            == "That sounds like things may be going okay right now. What would you like exercise to look like for you?")
    }

    @Test func leafTemplatedResponseLowercasesLeaf() {
        let path = ["Root", "Sense of Capability in Fitness", "Physical discomfort", "Fatigue"]
        #expect(CounselorEngine.templatedResponse(for: path)
            == "It sounds like fatigue is getting in the way. What feels most workable to change, even a little, this week?")
    }

    // MARK: - Full fallback path

    @MainActor
    @Test func fallbackResultUsesKeywordClassifierAndDefaults() {
        let engine = CounselorEngine()
        let result = engine.fallbackResult(userText: "no space in my dorm", error: "boom")
        #expect(result.stage == .contemplation)
        #expect(result.strategy == .reflect)
        #expect(result.barrierPath.last == "Tiny Living Space")
        #expect(result.counselorResponse
            == "It sounds like tiny living space is getting in the way. What feels most workable to change, even a little, this week?")
        #expect(result.error == "boom")
    }

    // MARK: - Initial session meta (exercise_app.py:297-303)

    @Test func initialMetaMatchesResetSession() {
        let initial = TurnResult.initial
        #expect(initial.stage == .contemplation)
        #expect(initial.barrierPath == ["Root"])
        #expect(initial.strategy == .openQuestion)
        #expect(initial.rationale == "Session initialized.")
        #expect(initial.confidence == nil)
    }

    @Test func greetingMatchesResetSession() {
        #expect(SessionSeed.greeting == "Hi. What has exercise been like for you lately?")
    }
}
