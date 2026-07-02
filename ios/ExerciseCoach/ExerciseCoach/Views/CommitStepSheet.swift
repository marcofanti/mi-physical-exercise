import SwiftData
import SwiftUI

/// Confirmation sheet for committing to a small next step. Appears when the
/// inferred stage reaches Preparation. Deliberately manual — the user edits
/// and confirms their own words; no LLM-based commitment extraction.
struct CommitStepSheet: View {
    let suggestedText: String
    let onCommit: (String, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var stepText: String
    @State private var remindAt: Date

    init(suggestedText: String, onCommit: @escaping (String, Date) -> Void) {
        self.suggestedText = suggestedText
        self.onCommit = onCommit
        _stepText = State(initialValue: suggestedText)
        // Default reminder: tomorrow 9:00.
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        let nineAM = Calendar.current.date(
            bySettingHour: 9, minute: 0, second: 0, of: tomorrow
        ) ?? tomorrow
        _remindAt = State(initialValue: nineAM)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("My next step") {
                    TextField("What will you try?", text: $stepText, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Check in with me") {
                    DatePicker(
                        "Reminder",
                        selection: $remindAt,
                        in: Date.now...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                Section {
                    Text("You'll get one notification asking how it went. You can delete it any time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Commit to a Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Commit") {
                        onCommit(
                            stepText.trimmingCharacters(in: .whitespacesAndNewlines),
                            remindAt
                        )
                        dismiss()
                    }
                    .disabled(stepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    CommitStepSheet(suggestedText: "Take a 10-minute walk after dinner tomorrow") { _, _ in }
}
