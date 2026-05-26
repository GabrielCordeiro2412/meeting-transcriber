import Foundation

struct RemoteMeetingSession: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var userID: String
    var createdAt: Date
    var startedAt: Date?
    var endedAt: Date?
    var title: String
    var status: RemoteMeetingStatus
    var captureMode: CaptureMode
    var transcriptText: String
    var summaryText: String
    var summaryPayload: MeetingSummaryResult
    var processingError: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case createdAt
        case startedAt
        case endedAt
        case title
        case status
        case captureMode
        case transcriptText
        case summaryText
        case summaryPayload
        case processingError
    }
}

enum RemoteMeetingStatus: String, Codable, Sendable {
    case draft
    case uploading
    case uploaded
    case transcribing
    case summarizing
    case completed
    case failed

    var localRecordingState: RecordingState {
        switch self {
        case .draft, .uploading, .uploaded:
            return .processingTranscript
        case .transcribing:
            return .processingTranscript
        case .summarizing:
            return .generatingSummary
        case .completed:
            return .completed
        case .failed:
            return .error
        }
    }
}
