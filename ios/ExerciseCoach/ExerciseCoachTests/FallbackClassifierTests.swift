import Testing
@testable import ExerciseCoach

/// Parity tests: every expected path below was pinned by running the Python
/// reference `fallback_classification` (exercise_app.py:149-164) on the same
/// probe. Do not "fix" surprising expectations — they encode tie-break
/// behavior (first-best leaf in document order wins).
struct FallbackClassifierTests {
    @Test func tiredAfterClass_tieGoesToDocumentOrder() {
        // "class" (Academic Overload) ties with "tired" (Fatigue) at 1;
        // Academic Overload appears first.
        #expect(FallbackClassifier.classify("I'm always so tired after class") == [
            "Root", "Sense of Personal Control over Exercise",
            "Schedule Constraints （When)", "Academic Overload",
        ])
    }

    @Test func dormSpace() {
        // "no space" + "dorm" score 2 for Tiny Living Space.
        #expect(FallbackClassifier.classify("no space in my dorm") == [
            "Root", "Sense of Personal Control over Exercise",
            "Limit of Environment & Resources (Where)", "Tiny Living Space",
        ])
    }

    @Test func planningConfusion() {
        #expect(FallbackClassifier.classify("I never know where to start or how to plan a routine") == [
            "Root", "Sense of Capability in Fitness",
            "Lack of skill & knowledge", "Unable to Plan",
        ])
    }

    @Test func gymJudged_tieGoesToNoEquipment() {
        // "gym" (No Equipment) ties with "judged" (Fear of Being Judged);
        // No Equipment appears first in document order — pinned Python behavior.
        #expect(FallbackClassifier.classify("everyone at the gym stares and I feel judged") == [
            "Root", "Sense of Personal Control over Exercise",
            "Limit of Environment & Resources (Where)", "No Equipment",
        ])
    }

    @Test func commuteAndWeather() {
        #expect(FallbackClassifier.classify("my commute is brutal and the weather is awful") == [
            "Root", "Sense of Personal Control over Exercise",
            "Schedule Constraints （When)", "Long Commute",
        ])
    }

    @Test func noMatchReturnsRoot() {
        #expect(FallbackClassifier.classify("xyzzy blorp") == ["Root"])
    }

    @Test func repeatedFailure() {
        #expect(FallbackClassifier.classify("I keep quitting, I tried before and it never sticks") == [
            "Root", "Sense of Capability in Fitness",
            "Past Exercise Ineffectiveness", "Repeated Failure",
        ])
    }

    @Test func noFriendsToGoWith() {
        #expect(FallbackClassifier.classify("I have no friends to go with and I hate going alone") == [
            "Root", "Relationships with Others in Fitness",
            "Sense of Belongs", "No Friends to Go With",
        ])
    }
}
