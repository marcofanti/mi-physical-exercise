import SwiftData
import SwiftUI

@main
struct ExerciseCoachApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            ChatSession.self,
            ChatMessage.self,
            TurnMetadata.self,
            CommittedStep.self,
        ])
    }
}
