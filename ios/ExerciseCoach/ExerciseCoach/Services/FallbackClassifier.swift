import Foundation

/// Keyword-based safety net used when the model call fails or misclassifies.
/// Verbatim port of `FALLBACK_KEYWORDS` (exercise_app.py:47-72) and
/// `fallback_classification` (exercise_app.py:149-164).
enum FallbackClassifier {
    static let keywords: [String: [String]] = [
        "Academic Overload": ["school", "class", "homework", "exam", "study", "assignment"],
        "Irregular Routine": ["routine", "schedule changes", "inconsistent", "random", "unpredictable"],
        "Long Commute": ["commute", "drive", "bus", "train", "travel"],
        "Tiny Living Space": ["small apartment", "tiny", "no space", "room", "dorm"],
        "No Equipment": ["equipment", "gym", "weights", "machine", "treadmill"],
        "Outdoor Access Only": ["outside", "outdoor", "weather", "rain", "cold", "hot"],
        "Lack of Alternative Moves": ["alternative", "modify", "modification", "can't do", "hurts"],
        "Lack of Intensity adjustment": ["too hard", "too intense", "intensity", "overdo"],
        "Lack of Pace & Rest Management": ["pace", "rest", "break", "burn out", "exhausted"],
        "Fatigue": ["tired", "fatigue", "exhausted", "low energy", "drained"],
        "Slow Recovery": ["sore", "recover", "recovery", "pain after", "days after"],
        "Poor Conditioning": ["out of shape", "winded", "conditioning", "unfit", "stamina"],
        "Lack Exercise Experience": ["never exercised", "beginner", "new to exercise", "experience"],
        "Unable to Plan": ["plan", "where to start", "don't know what", "routine"],
        "Lack fitness knowledge and skill": ["knowledge", "skill", "form", "technique", "how to"],
        "Repeated Failure": ["failed", "quit", "tried before", "never sticks", "give up"],
        "Lack of Visible Progress": ["progress", "results", "nothing changes", "not working"],
        "Lack Connections to the community": ["community", "belong", "group", "class"],
        "No Friends to Go With": ["friend", "alone", "partner", "go with"],
        "Fear of Being Judged": ["judged", "embarrassed", "people watching", "self-conscious"],
        "Interpersonal Recognition & Inclusion": ["included", "recognized", "fit in", "left out"],
        "Lack Shared Goals & Collaboration": ["same goals", "collaborate", "together", "accountability"],
        "Lack Encouragement & Constructive Feedback": ["encouragement", "feedback", "support", "criticized"],
        "Lack Reciprocal monitoring": ["checking in", "monitor", "accountability", "remind"],
    ]

    /// Scores every leaf by counting matching terms (leaf name + keywords) in
    /// the lowercased user text; first-best wins ties (leaves in document
    /// order, strict `>` comparison — exactly like the Python loop).
    /// Zero matches → [Root].
    static func classify(_ userText: String) -> [String] {
        let lowered = userText.lowercased()
        var bestLeaf: String?
        var bestScore = 0

        for leaf in DecisionTree.leafLabels {
            let terms = [leaf.lowercased()] + (keywords[leaf] ?? [])
            let score = terms.count { !$0.isEmpty && lowered.contains($0) }
            if score > bestScore {
                bestLeaf = leaf
                bestScore = score
            }
        }

        guard let leaf = bestLeaf, let path = DecisionTree.path(to: leaf) else {
            return [DecisionTree.rootLabel]
        }
        return path
    }
}
