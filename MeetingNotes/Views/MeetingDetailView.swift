import SwiftUI

struct MeetingDetailView: View {
    @EnvironmentObject private var coordinator: MeetingCoordinator
    let session: MeetingSession

    @State private var isEditing = false
    @State private var title = ""
    @State private var summary = ""
    @State private var detailedNotes = ""
    @State private var topics = ""
    @State private var keyPoints = ""
    @State private var decisions = ""
    @State private var actionItems = ""
    @State private var risksOrBlockers = ""
    @State private var followUpItems = ""
    @State private var openQuestions = ""
    @State private var transcript = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let processingError = session.processingError, !processingError.isEmpty {
                    Label(processingError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }

                if isEditing {
                    editableContent
                } else {
                    readOnlyContent
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(session.title)
        .toolbar {
            if isEditing {
                Button("Cancel") {
                    loadDraft()
                    isEditing = false
                }

                Button {
                    saveDraft()
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .keyboardShortcut("s", modifiers: .command)
            } else {
                Button {
                    isEditing = true
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
            }
        }
        .onAppear(perform: loadDraft)
        .onChange(of: session.id) { _, _ in
            loadDraft()
            isEditing = false
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                TextField("Meeting title", text: $title)
                    .font(.largeTitle.bold())
                    .textFieldStyle(.plain)
            } else {
                Text(session.title)
                    .font(.largeTitle.bold())
            }

            HStack(spacing: 14) {
                Label(session.status.label, systemImage: session.status.systemImage)
                Label(session.captureMode.label, systemImage: "waveform")

                if let duration = session.duration {
                    Label(durationText(duration), systemImage: "timer")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private var readOnlyContent: some View {
        Group {
            SectionView(title: "Summary", systemImage: "text.badge.checkmark") {
                Text(emptyFallback(session.summaryText))
                    .textSelection(.enabled)
            }

            SectionListView(title: "Detailed Notes", systemImage: "doc.text.magnifyingglass", items: session.detailedNotes ?? [])
            SectionListView(title: "Topics", systemImage: "tag", items: session.topics ?? [])
            SectionListView(title: "Key Points", systemImage: "checklist", items: session.keyPoints)
            SectionListView(title: "Decisions", systemImage: "checkmark.seal", items: session.decisions)
            SectionListView(title: "Action Items", systemImage: "arrowshape.turn.up.right", items: session.actionItems)
            SectionListView(title: "Risks or Blockers", systemImage: "exclamationmark.octagon", items: session.risksOrBlockers ?? [])
            SectionListView(title: "Follow-ups", systemImage: "arrow.triangle.2.circlepath", items: session.followUpItems ?? [])
            SectionListView(title: "Open Questions", systemImage: "questionmark.circle", items: session.openQuestions)

            SectionView(title: "Transcript", systemImage: "doc.plaintext") {
                Text(emptyFallback(session.transcriptText))
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }
        }
    }

    private var editableContent: some View {
        Group {
            EditableTextSection(title: "Summary", systemImage: "text.badge.checkmark", text: $summary, minHeight: 120)
            EditableTextSection(title: "Detailed Notes", systemImage: "doc.text.magnifyingglass", text: $detailedNotes)
            EditableTextSection(title: "Topics", systemImage: "tag", text: $topics, help: "One topic per line.")
            EditableTextSection(title: "Key Points", systemImage: "checklist", text: $keyPoints)
            EditableTextSection(title: "Decisions", systemImage: "checkmark.seal", text: $decisions)
            EditableTextSection(title: "Action Items", systemImage: "arrowshape.turn.up.right", text: $actionItems)
            EditableTextSection(title: "Risks or Blockers", systemImage: "exclamationmark.octagon", text: $risksOrBlockers)
            EditableTextSection(title: "Follow-ups", systemImage: "arrow.triangle.2.circlepath", text: $followUpItems)
            EditableTextSection(title: "Open Questions", systemImage: "questionmark.circle", text: $openQuestions)
            EditableTextSection(title: "Transcript", systemImage: "doc.plaintext", text: $transcript, minHeight: 220, monospaced: true)
        }
    }

    private func loadDraft() {
        title = session.title
        summary = session.summaryText
        detailedNotes = joined(session.detailedNotes ?? [])
        topics = joined(session.topics ?? [])
        keyPoints = joined(session.keyPoints)
        decisions = joined(session.decisions)
        actionItems = joined(session.actionItems)
        risksOrBlockers = joined(session.risksOrBlockers ?? [])
        followUpItems = joined(session.followUpItems ?? [])
        openQuestions = joined(session.openQuestions)
        transcript = session.transcriptText
    }

    private func saveDraft() {
        coordinator.saveSessionEdits(
            sessionId: session.id,
            title: title,
            summary: summary,
            detailedNotes: lines(from: detailedNotes),
            topics: lines(from: topics),
            keyPoints: lines(from: keyPoints),
            decisions: lines(from: decisions),
            actionItems: lines(from: actionItems),
            risksOrBlockers: lines(from: risksOrBlockers),
            followUpItems: lines(from: followUpItems),
            openQuestions: lines(from: openQuestions),
            transcript: transcript
        )
        isEditing = false
    }

    private func joined(_ values: [String]) -> String {
        values.joined(separator: "\n")
    }

    private func lines(from value: String) -> [String] {
        value
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func emptyFallback(_ value: String) -> String {
        value.isEmpty ? "No content yet." : value
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }
}

private struct SectionView<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SectionListView: View {
    let title: String
    let systemImage: String
    let items: [String]

    var body: some View {
        SectionView(title: title, systemImage: systemImage) {
            if items.isEmpty {
                Text("No items yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Label(item, systemImage: "circle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
    }
}

private struct EditableTextSection: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    var help: String?
    var minHeight: CGFloat = 96
    var monospaced = false

    var body: some View {
        SectionView(title: title, systemImage: systemImage) {
            VStack(alignment: .leading, spacing: 6) {
                TextEditor(text: $text)
                    .font(monospaced ? .body.monospaced() : .body)
                    .frame(minHeight: minHeight)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    )

                if let help {
                    Text(help)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
