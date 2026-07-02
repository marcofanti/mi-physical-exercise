import SwiftUI

/// First-launch disclaimer: research prototype, not medical advice.
/// Health-adjacent apps get reviewer attention — this is shown once and
/// recorded in UserDefaults.
struct DisclaimerView: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.walk.motion")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Welcome to ExerciseCoach")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 14) {
                disclaimerRow(
                    icon: "graduationcap",
                    text: "This is a student research prototype exploring "
                        + "motivational-interviewing conversations about exercise."
                )
                disclaimerRow(
                    icon: "cross.case",
                    text: "It is not medical advice, diagnosis, or treatment. "
                        + "Talk to a healthcare professional before changing your "
                        + "exercise routine."
                )
                disclaimerRow(
                    icon: "lock.shield",
                    text: "Everything runs on your iPhone. Conversations, health "
                        + "data, and speech never leave your device."
                )
            }
            .padding(.horizontal)

            Spacer()

            Button {
                onAccept()
            } label: {
                Text("I Understand")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func disclaimerRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DisclaimerView {}
}
