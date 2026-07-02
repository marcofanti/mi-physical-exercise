import Testing
@testable import ExerciseCoach

struct DecisionTreeTests {
    /// Pinned from the Python reference: `len(LEAF_NODES) == 24`.
    @Test func leafCount() {
        #expect(DecisionTree.leafLabels.count == 24)
    }

    /// Every leaf label matches the markdown source character-for-character,
    /// in document order.
    @Test func leafLabelsVerbatimAndOrdered() {
        let expected = [
            "Academic Overload",
            "Irregular Routine",
            "Long Commute",
            "Tiny Living Space",
            "No Equipment",
            "Outdoor Access Only",
            "Lack of Alternative Moves",
            "Lack of Intensity adjustment",
            "Lack of Pace & Rest Management",
            "Fatigue",
            "Slow Recovery",
            "Poor Conditioning",
            "Lack Exercise Experience",
            "Unable to Plan",
            "Lack fitness knowledge and skill",
            "Repeated Failure",
            "Lack of Visible Progress",
            "Lack Connections to the community",
            "No Friends to Go With",
            "Fear of Being Judged",
            "Interpersonal Recognition & Inclusion",
            "Lack Shared Goals & Collaboration",
            "Lack Encouragement & Constructive Feedback",
            "Lack Reciprocal monitoring",
        ]
        #expect(DecisionTree.leafLabels == expected)
    }

    /// The full-width paren quirk from the pptx-derived markdown must survive.
    @Test func fullWidthParenPreserved() {
        #expect(DecisionTree.allLabels.contains("Schedule Constraints （When)"))
        #expect(DecisionTree.path(to: "Academic Overload")?[2] == "Schedule Constraints （When)")
    }

    /// Every FALLBACK_KEYWORDS key is a real leaf (pinned Python:
    /// `set(FALLBACK_KEYWORDS) == set(LEAF_NODES)` is True).
    @Test func keywordKeysMatchLeaves() {
        #expect(Set(FallbackClassifier.keywords.keys) == Set(DecisionTree.leafLabels))
    }

    @Test func pathToLeafAndRoot() {
        #expect(DecisionTree.path(to: "Fatigue") == [
            "Root", "Sense of Capability in Fitness", "Physical discomfort", "Fatigue",
        ])
        #expect(DecisionTree.path(to: "Root") == ["Root"])
        #expect(DecisionTree.path(to: "Not A Node") == nil)
    }

    /// Byte-for-byte parity with Python's LEAF_PATH_TEXT (exercise_app.py:121-123),
    /// pinned by running the reference implementation.
    @Test func leafPathTextMatchesPython() {
        let expected = """
            - Root > Sense of Personal Control over Exercise > Schedule Constraints （When) > Academic Overload
            - Root > Sense of Personal Control over Exercise > Schedule Constraints （When) > Irregular Routine
            - Root > Sense of Personal Control over Exercise > Schedule Constraints （When) > Long Commute
            - Root > Sense of Personal Control over Exercise > Limit of Environment & Resources (Where) > Tiny Living Space
            - Root > Sense of Personal Control over Exercise > Limit of Environment & Resources (Where) > No Equipment
            - Root > Sense of Personal Control over Exercise > Limit of Environment & Resources (Where) > Outdoor Access Only
            - Root > Sense of Personal Control over Exercise > Inflexible Execution (How) > Lack of Alternative Moves
            - Root > Sense of Personal Control over Exercise > Inflexible Execution (How) > Lack of Intensity adjustment
            - Root > Sense of Personal Control over Exercise > Inflexible Execution (How) > Lack of Pace & Rest Management
            - Root > Sense of Capability in Fitness > Physical discomfort > Fatigue
            - Root > Sense of Capability in Fitness > Physical discomfort > Slow Recovery
            - Root > Sense of Capability in Fitness > Physical discomfort > Poor Conditioning
            - Root > Sense of Capability in Fitness > Lack of skill & knowledge > Lack Exercise Experience
            - Root > Sense of Capability in Fitness > Lack of skill & knowledge > Unable to Plan
            - Root > Sense of Capability in Fitness > Lack of skill & knowledge > Lack fitness knowledge and skill
            - Root > Sense of Capability in Fitness > Past Exercise Ineffectiveness > Repeated Failure
            - Root > Sense of Capability in Fitness > Past Exercise Ineffectiveness > Lack of Visible Progress
            - Root > Relationships with Others in Fitness > Sense of Belongs > Lack Connections to the community
            - Root > Relationships with Others in Fitness > Sense of Belongs > No Friends to Go With
            - Root > Relationships with Others in Fitness > Sense of Belongs > Fear of Being Judged
            - Root > Relationships with Others in Fitness > Sense of Belongs > Interpersonal Recognition & Inclusion
            - Root > Relationships with Others in Fitness > Lack of Mutual Support > Lack Shared Goals & Collaboration
            - Root > Relationships with Others in Fitness > Lack of Mutual Support > Lack Encouragement & Constructive Feedback
            - Root > Relationships with Others in Fitness > Lack of Mutual Support > Lack Reciprocal monitoring
            """
        #expect(DecisionTree.leafPathText == expected)
    }
}
