import SwiftUI

struct MeetingHistoryView: View {
    @EnvironmentObject private var coordinator: MeetingCoordinator

    var body: some View {
        NavigationSplitView {
            List(selection: selectedBinding) {
                ForEach(coordinator.sessions) { session in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(session.title)
                            .font(.headline)
                            .lineLimit(1)

                        HStack {
                            Label(session.status.label, systemImage: session.status.systemImage)
                            Text(session.createdAt, style: .date)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .tag(session.id)
                    .contextMenu {
                        Button {
                            coordinator.selectSession(session)
                            coordinator.retryProcessingSelectedSession()
                        } label: {
                            Label("Reprocess", systemImage: "arrow.clockwise.circle")
                        }

                        Button(role: .destructive) {
                            coordinator.deleteMeetingSession(sessionId: session.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Meetings")
            .toolbar {
                Button {
                    coordinator.fetchMeetingHistory()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
            }
        } detail: {
            if let session = coordinator.selectedSession {
                MeetingDetailView(session: session)
            } else {
                ContentUnavailableView(
                    "No meeting selected",
                    systemImage: "waveform",
                    description: Text("Start a recording from the menu bar.")
                )
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var selectedBinding: Binding<UUID?> {
        Binding(
            get: { coordinator.selectedSession?.id },
            set: { id in
                coordinator.selectSession(coordinator.sessions.first { $0.id == id })
            }
        )
    }
}
