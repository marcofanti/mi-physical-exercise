import Foundation

/// One node of the V8 exercise-barrier decision tree.
struct TreeNode: Identifiable, Hashable, Sendable {
    let label: String
    let children: [TreeNode]

    var id: String { label }
    var isLeaf: Bool { children.isEmpty }

    init(_ label: String, _ children: [TreeNode] = []) {
        self.label = label
        self.children = children
    }
}

/// Static port of `V8-Decision Tree.md`.
///
/// Labels are copied CHARACTER-FOR-CHARACTER from the markdown source,
/// including quirks like the full-width paren in "Schedule Constraints （When)"
/// and inconsistent capitalization ("Lack of Intensity adjustment",
/// "Sense of Belongs", "Lack Reciprocal monitoring"). Classification paths
/// stay canonical only if these labels never drift — see DecisionTreeTests.
enum DecisionTree {
    static let rootLabel = "Root"

    static let root = TreeNode(rootLabel, [
        TreeNode("Sense of Personal Control over Exercise", [
            TreeNode("Schedule Constraints （When)", [
                TreeNode("Academic Overload"),
                TreeNode("Irregular Routine"),
                TreeNode("Long Commute"),
            ]),
            TreeNode("Limit of Environment & Resources (Where)", [
                TreeNode("Tiny Living Space"),
                TreeNode("No Equipment"),
                TreeNode("Outdoor Access Only"),
            ]),
            TreeNode("Inflexible Execution (How)", [
                TreeNode("Lack of Alternative Moves"),
                TreeNode("Lack of Intensity adjustment"),
                TreeNode("Lack of Pace & Rest Management"),
            ]),
        ]),
        TreeNode("Sense of Capability in Fitness", [
            TreeNode("Physical discomfort", [
                TreeNode("Fatigue"),
                TreeNode("Slow Recovery"),
                TreeNode("Poor Conditioning"),
            ]),
            TreeNode("Lack of skill & knowledge", [
                TreeNode("Lack Exercise Experience"),
                TreeNode("Unable to Plan"),
                TreeNode("Lack fitness knowledge and skill"),
            ]),
            TreeNode("Past Exercise Ineffectiveness", [
                TreeNode("Repeated Failure"),
                TreeNode("Lack of Visible Progress"),
            ]),
        ]),
        TreeNode("Relationships with Others in Fitness", [
            TreeNode("Sense of Belongs", [
                TreeNode("Lack Connections to the community"),
                TreeNode("No Friends to Go With"),
                TreeNode("Fear of Being Judged"),
                TreeNode("Interpersonal Recognition & Inclusion"),
            ]),
            TreeNode("Lack of Mutual Support", [
                TreeNode("Lack Shared Goals & Collaboration"),
                TreeNode("Lack Encouragement & Constructive Feedback"),
                TreeNode("Lack Reciprocal monitoring"),
            ]),
        ]),
    ])

    /// label → parent label, built once by pre-order walk.
    /// Mirrors `PARENTS` from `parse_markdown_tree` (exercise_app.py:75-103).
    static let parents: [String: String?] = {
        var result: [String: String?] = [rootLabel: nil]
        func walk(_ node: TreeNode) {
            for child in node.children {
                result[child.label] = node.label
                walk(child)
            }
        }
        walk(root)
        return result
    }()

    /// All node labels in document (pre-order) order — mirrors `ALL_NODES`.
    static let allLabels: [String] = {
        var labels: [String] = []
        func walk(_ node: TreeNode) {
            labels.append(node.label)
            node.children.forEach(walk)
        }
        walk(root)
        return labels
    }()

    /// Leaf labels in document order — mirrors `LEAF_NODES` (exercise_app.py:108).
    static let leafLabels: [String] = {
        var labels: [String] = []
        func walk(_ node: TreeNode) {
            if node.isLeaf, node.label != rootLabel {
                labels.append(node.label)
            }
            node.children.forEach(walk)
        }
        walk(root)
        return labels
    }()

    /// Root→node path for a label, or nil if the label is not in the tree.
    /// Mirrors `path_to_node` (exercise_app.py:111-117).
    static func path(to label: String) -> [String]? {
        guard parents.keys.contains(label) else { return nil }
        var path = [label]
        var current = label
        while let parent = parents[current] ?? nil {
            path.append(parent)
            current = parent
        }
        return path.reversed()
    }

    /// The leaf-path block injected into the system prompt.
    /// Must match Python's `LEAF_PATH_TEXT` (exercise_app.py:121-123) byte-for-byte.
    static let leafPathText: String = leafLabels
        .compactMap { leaf in path(to: leaf).map { "- \($0.joined(separator: " > "))" } }
        .joined(separator: "\n")
}
