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
    var audioChunksData: Data?
    var processingError: String?
    var summaryLanguageRawValue: String?

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
        audioChunks: [MeetingAudioChunk] = [],
        processingError: String? = nil,
        summaryLanguageRawValue: String? = nil
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
        self.audioChunksData = try? JSONEncoder().encode(audioChunks)
        self.processingError = processingError
        self.summaryLanguageRawValue = summaryLanguageRawValue
    }

    var summaryLanguagePreference: SummaryLanguagePreference? {
        guard let summaryLanguageRawValue else { return nil }
        return SummaryLanguagePreference(rawValue: summaryLanguageRawValue)
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

    var audioChunks: [MeetingAudioChunk] {
        get {
            guard let audioChunksData else { return [] }
            return (try? JSONDecoder().decode([MeetingAudioChunk].self, from: audioChunksData)) ?? []
        }
        set {
            audioChunksData = try? JSONEncoder().encode(newValue)
        }
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

}
