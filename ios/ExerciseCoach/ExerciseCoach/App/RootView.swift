import FoundationModels
import SwiftUI

/// Availability gate: chat when the on-device model is usable, otherwise an
/// explanatory screen. Shows the one-time research disclaimer first.
/// Availability is re-evaluated when the app returns to the foreground
/// (e.g. after the user enables Apple Intelligence in Settings).
struct RootView: View {
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false
    @State private var availability = SystemLanguageModel.default.availability
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !hasAcceptedDisclaimer {
                DisclaimerView {
                    hasAcceptedDisclaimer = true
                }
            } else {
                switch availability {
                case .available:
                    ChatView()
                case .unavailable(let reason):
                    ModelUnavailableView(reason: reason)
                }
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                availability = SystemLanguageModel.default.availability
            }
        }
    }
}

#Preview {
    RootView()
}
