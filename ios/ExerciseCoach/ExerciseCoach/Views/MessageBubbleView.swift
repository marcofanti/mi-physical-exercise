import SwiftUI

struct MessageBubbleView: View {
    let message: TranscriptMessage
    /// When set, counselor bubbles show a replay-speech affordance.
    var onSpeak: ((String) -> Void)?

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isUser { Spacer(minLength: 48) }

            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser ? Color.accentColor : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .foregroundStyle(isUser ? .white : .primary)

            if !isUser, let onSpeak {
                Button {
                    onSpeak(message.content)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Speak this reply")
            }

            if !isUser { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubbleView(
            message: TranscriptMessage(role: .assistant, content: SessionSeed.greeting),
            onSpeak: { _ in }
        )
        MessageBubbleView(message: TranscriptMessage(role: .user, content: "My class schedule is insane lately."))
    }
    .padding()
}
