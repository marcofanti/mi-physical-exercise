import SwiftUI

/// Recursive renderer of the V8 barrier tree with the current classification
/// path highlighted — ports `render_tree` (exercise_app.py:276-285).
struct DecisionTreeView: View {
    let selectedPath: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TreeNodeRowView(node: DecisionTree.root, depth: 0, selectedPath: selectedPath)
        }
    }
}

private struct TreeNodeRowView: View {
    let node: TreeNode
    let depth: Int
    let selectedPath: [String]

    private var isSelected: Bool { selectedPath.contains(node.label) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 5, height: 5)
                Text(node.label)
                    .font(depth == 0 ? .subheadline.weight(.semibold) : .subheadline)
                    .fontWeight(isSelected ? .bold : nil)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
            }
            .padding(.leading, CGFloat(depth) * 16)

            ForEach(node.children) { child in
                TreeNodeRowView(node: child, depth: depth + 1, selectedPath: selectedPath)
            }
        }
    }
}

#Preview {
    ScrollView {
        DecisionTreeView(selectedPath: [
            "Root", "Sense of Capability in Fitness", "Physical discomfort", "Fatigue",
        ])
        .padding()
    }
}
