import SwiftData
import SwiftUI

/// Entry point of the chat UI. Creates the view model once the SwiftData
/// context is available from the environment.
struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChatViewModel?

    var body: some View {
        Group {
            if let viewModel {
                ChatContentView(viewModel: viewModel)
            } else {
                ProgressView()
                    .task { viewModel = ChatViewModel(context: modelContext) }
            }
        }
    }
}

private struct ChatContentView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var draft = ""
    @State private var showDetailSheet = false
    @State private var showCommitSheet = false
    @State private var voiceController: VoiceConversationController?
    @FocusState private var inputFocused: Bool

    private var router: NotificationRouter { .shared }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MIStateChipsView(meta: viewModel.meta) {
                    showDetailSheet = true
                }
                Divider()
                messageList
                if let voiceController, voiceController.isActive || voiceController.errorMessage != nil {
                    VoiceModeOverlay(controller: voiceController)
                        .padding(.bottom, 4)
                }
                inputBar
            }
            .task {
                setUpVoiceController()
                await viewModel.refreshHealthContext()
            }
            .onChange(of: router.pendingCheckInStep) {
                guard let step = router.pendingCheckInStep else { return }
                viewModel.startCheckIn(stepText: step, completed: router.pendingCheckInCompleted)
                router.pendingCheckInStep = nil
                router.pendingCheckInCompleted = false
            }
            .navigationTitle("Exercise Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: "history") {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Session", systemImage: "square.and.pencil") {
                        viewModel.reset()
                    }
                }
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "history" {
                    SessionListView()
                }
            }
            .sheet(isPresented: $showDetailSheet) {
                MIDetailSheet(meta: viewModel.meta, turnCount: viewModel.turnCount)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCommitSheet) {
                CommitStepSheet(suggestedText: viewModel.lastUserMessage) { text, remindAt in
                    Task { await viewModel.commitStep(text: text, remindAt: remindAt) }
                }
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message, onSpeak: speakReply)
                            .id(message.id)
                    }
                    if viewModel.isThinking {
                        thinkingIndicator
                            .id("thinking")
                    }
                    if viewModel.showsCommitAffordance, !viewModel.isThinking {
                        commitAffordance
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) {
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: viewModel.isThinking) {
                if viewModel.isThinking {
                    withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                }
            }
        }
    }

    private var commitAffordance: some View {
        Button {
            showCommitSheet = true
        } label: {
            Label("Commit to a next step", systemImage: "checkmark.circle")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.15), in: Capsule())
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var thinkingIndicator: some View {
        HStack {
            ProgressView()
            Text("Thinking…")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(
                "What makes exercise hard right now…",
                text: $draft,
                axis: .vertical
            )
            .lineLimit(1...4)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemBackground), in: Capsule())
            .focused($inputFocused)
            .onSubmit(sendDraft)

            Button(action: toggleVoiceMode) {
                Image(systemName: micIcon)
                    .font(.system(size: 24))
                    .foregroundStyle(voiceController?.isActive == true ? Color.red : Color.accentColor)
            }
            .accessibilityLabel(voiceController?.isActive == true ? "Stop voice conversation" : "Start voice conversation")

            Button(action: sendDraft) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isThinking)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var micIcon: String {
        switch voiceController?.state {
        case .speaking: "stop.circle.fill"
        case .listening, .thinking: "mic.circle.fill"
        default: "mic.circle"
        }
    }

    private func setUpVoiceController() {
        guard voiceController == nil else { return }
        voiceController = VoiceConversationController { [viewModel] text in
            await viewModel.send(text)
            return viewModel.messages.last?.content ?? ""
        }
    }

    private func toggleVoiceMode() {
        inputFocused = false
        voiceController?.toggle()
    }

    private func speakReply(_ text: String) {
        guard let voiceController, !voiceController.isActive else { return }
        voiceController.speechOutput.speak(text)
    }

    private func sendDraft() {
        let text = draft
        draft = ""
        Task { await viewModel.send(text) }
    }
}

#Preview {
    ChatView()
        .modelContainer(
            for: [ChatSession.self, ChatMessage.self, TurnMetadata.self, CommittedStep.self],
            inMemory: true
        )
}
