import FoundationModels
import SwiftUI

/// Shown when the on-device model can't run — older hardware, Apple
/// Intelligence disabled, or model assets still downloading.
struct ModelUnavailableView: View {
    let reason: SystemLanguageModel.Availability.UnavailableReason

    var body: some View {
        ContentUnavailableView {
            Label("Apple Intelligence Required", systemImage: "brain.head.profile")
        } description: {
            Text(message)
        } actions: {
            if showsSettingsButton {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var message: String {
        switch reason {
        case .deviceNotEligible:
            "ExerciseCoach runs its counselor entirely on your device, which "
                + "requires an iPhone that supports Apple Intelligence "
                + "(iPhone 15 Pro or later)."
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is turned off. Enable it in "
                + "Settings > Apple Intelligence & Siri, then come back."
        case .modelNotReady:
            "The on-device model is still downloading or preparing. "
                + "Keep your iPhone on Wi-Fi and power, and try again shortly."
        @unknown default:
            "The on-device model is currently unavailable on this iPhone."
        }
    }

    private var showsSettingsButton: Bool {
        if case .appleIntelligenceNotEnabled = reason { return true }
        return false
    }
}
