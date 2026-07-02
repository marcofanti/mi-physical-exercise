import SwiftUI

/// Hands-free mode banner: shows the loop state and live transcript while
/// voice conversation is active.
struct VoiceModeOverlay: View {
    let controller: VoiceConversationController

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                stateIndicator
                Text(stateLabel)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("End", systemImage: "xmark.circle.fill") {
                    controller.stop()
                }
                .labelStyle(.titleAndIcon)
                .font(.subheadline)
            }

            if controller.state == .listening {
                Text(controller.liveTranscript.isEmpty ? "Listening…" : controller.liveTranscript)
                    .font(.callout)
                    .foregroundStyle(controller.liveTranscript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
            }

            if let error = controller.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
    }

    private var stateLabel: String {
        switch controller.state {
        case .idle: "Voice off"
        case .listening: "Listening"
        case .thinking: "Thinking…"
        case .speaking: "Speaking — tap mic to interrupt"
        }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch controller.state {
        case .listening:
            Image(systemName: "waveform")
                .symbolEffect(.variableColor.iterative, options: .repeating)
                .foregroundStyle(.green)
        case .thinking:
            ProgressView()
                .controlSize(.small)
        case .speaking:
            Image(systemName: "speaker.wave.2.fill")
                .symbolEffect(.pulse, options: .repeating)
                .foregroundStyle(.blue)
        case .idle:
            Image(systemName: "mic.slash")
                .foregroundStyle(.secondary)
        }
    }
}
