import Foundation
import SwiftData

@Model
final class MeetingSession {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var startedAt: Date?
    var endedAt: Date?
    var title: String
    var statusRawValue: String
    var audioFileURL: String?
    var systemAudioFileURL: String?
    var transcriptText: String
    var summaryText: String
    var detailedNotes: [String]?
    var topics: [String]?
    var keyPoints: [String]
    var decisions: [String]
    var actionItems: [String]
    var openQuestions: [String]
    var risksOrBlockers: [String]?
    var followUpItems: [String]?
    var captureModeRawValue: String
    var syncStateRawValue: String
    var processingError: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        title: String,
        status: RecordingState = .idle,
        audioFileURL: String? = nil,
        systemAudioFileURL: String? = nil,
        transcriptText: String = "",
        summaryText: String = "",
        detailedNotes: [String] = [],
        topics: [String] = [],
        keyPoints: [String] = [],
        decisions: [String] = [],
        actionItems: [String] = [],
        openQuestions: [String] = [],
        risksOrBlockers: [String] = [],
        followUpItems: [String] = [],
        captureMode: CaptureMode = .microphoneOnly,
        syncState: MeetingSyncState = .localOnly,
        processingError: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.title = title
        self.statusRawValue = status.rawValue
        self.audioFileURL = audioFileURL
        self.systemAudioFileURL = systemAudioFileURL
        self.transcriptText = transcriptText
        self.summaryText = summaryText
        self.detailedNotes = detailedNotes
        self.topics = topics
        self.keyPoints = keyPoints
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.risksOrBlockers = risksOrBlockers
        self.followUpItems = followUpItems
        self.captureModeRawValue = captureMode.rawValue
        self.syncStateRawValue = syncState.rawValue
        self.processingError = processingError
    }

    var status: RecordingState {
        get { RecordingState(rawValue: statusRawValue) ?? .idle }
        set { statusRawValue = newValue.rawValue }
    }

    var captureMode: CaptureMode {
        get { CaptureMode(rawValue: captureModeRawValue) ?? .microphoneOnly }
        set { captureModeRawValue = newValue.rawValue }
    }

    var syncState: MeetingSyncState {
        get { MeetingSyncState(rawValue: syncStateRawValue) ?? .localOnly }
        set { syncStateRawValue = newValue.rawValue }
    }

    var duration: TimeInterval? {
        guard let startedAt, let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    func apply(summary result: MeetingSummaryResult) {
        if !result.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = result.title
        }
        summaryText = result.summary
        detailedNotes = result.detailedNotes
        topics = result.topics
        keyPoints = result.keyPoints
        decisions = result.decisions
        actionItems = result.actionItems
        openQuestions = result.openQuestions
        risksOrBlockers = result.risksOrBlockers
        followUpItems = result.followUpItems
    }

    func apply(remote session: RemoteMeetingSession) {
        title = session.title
        createdAt = session.createdAt
        startedAt = session.startedAt
        endedAt = session.endedAt
        captureMode = session.captureMode
        transcriptText = session.transcriptText
        summaryText = session.summaryText
        processingError = session.processingError
        status = session.status.localRecordingState
        syncState = .synced
        apply(summary: session.summaryPayload)
    }
}
