import SwiftData
import SwiftUI

/// Browser for past sessions, persisted in SwiftData.
struct SessionListView: View {
    @Query(sort: \ChatSession.startedAt, order: .reverse)
    private var sessions: [ChatSession]
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Past Sessions",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Conversations are saved here after your first message.")
                )
            } else {
                List {
                    ForEach(sessions) { session in
                        NavigationLink(value: session) {
                            row(for: session)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("History")
        .navigationDestination(for: ChatSession.self) { session in
            SessionTranscriptView(session: session)
        }
    }

    private func row(for session: ChatSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title.isEmpty ? "Session" : session.title)
                .lineLimit(1)
            HStack(spacing: 8) {
                Text(session.startedAt, format: .dateTime.month().day().hour().minute())
                Text("·")
                Text("\(session.turnCount) turns")
                Text("·")
                HStack(spacing: 4) {
                    Circle()
                        .fill(session.lastStage.tint)
                        .frame(width: 7, height: 7)
                    Text(session.lastStage.rawValue)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sessions[index])
        }
        try? context.save()
    }
}

/// Read-only transcript of a past session.
struct SessionTranscriptView: View {
    let session: ChatSession

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(session.sortedMessages) { message in
                    MessageBubbleView(message: message.asTranscriptMessage)
                }
            }
            .padding()
        }
        .navigationTitle(session.startedAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}
