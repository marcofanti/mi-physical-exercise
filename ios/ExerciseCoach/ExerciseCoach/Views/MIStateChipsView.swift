import SwiftUI

/// Compact, always-visible MI state — the mobile adaptation of the Streamlit
/// sidebar metrics (exercise_app.py:357-372). Tap any chip for the detail sheet.
struct MIStateChipsView: View {
    let meta: TurnResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(
                        icon: "figure.mind.and.body",
                        text: meta.stage.rawValue,
                        tint: meta.stage.tint
                    )
                    chip(
                        icon: "point.topleft.down.to.point.bottomright.curvepath",
                        text: meta.barrierLeaf,
                        tint: .blue
                    )
                    chip(
                        icon: "bubble.left.and.text.bubble.right",
                        text: meta.strategy.rawValue,
                        tint: .purple
                    )
                }
                .padding(.horizontal)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .background(.bar)
        .accessibilityLabel(
            "Stage \(meta.stage.rawValue), barrier \(meta.barrierLeaf), strategy \(meta.strategy.rawValue). Tap for details."
        )
    }

    private func chip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.14), in: Capsule())
        .foregroundStyle(tint)
    }
}

extension Stage {
    /// Traffic-light coloring matching the CLAUDE.md convention
    /// (🔴 Precontemplation / 🟡 Contemplation / 🟢 Preparation).
    var tint: Color {
        switch self {
        case .precontemplation: .red
        case .contemplation: .orange
        case .preparation: .green
        }
    }
}
