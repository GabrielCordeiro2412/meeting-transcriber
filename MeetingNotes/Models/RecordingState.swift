import Foundation

enum RecordingState: String, Codable, CaseIterable, Sendable {
    case idle
    case requestingPermissions
    case recording
    case paused
    case processingTranscript
    case generatingSummary
    case completed
    case error

    var label: String {
        switch self {
        case .idle: "Ready"
        case .requestingPermissions: "Requesting permissions"
        case .recording: "Recording"
        case .paused: "Paused"
        case .processingTranscript: "Transcribing"
        case .generatingSummary: "Summarizing"
        case .completed: "Completed"
        case .error: "Needs attention"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: "waveform"
        case .requestingPermissions: "lock.shield"
        case .recording: "record.circle.fill"
        case .paused: "pause.circle.fill"
        case .processingTranscript: "waveform.badge.magnifyingglass"
        case .generatingSummary: "text.badge.checkmark"
        case .completed: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }
}

enum CaptureMode: String, Codable, CaseIterable, Sendable {
    case microphoneOnly
    case microphoneAndSystemAudio

    var label: String {
        switch self {
        case .microphoneOnly: "Microphone only"
        case .microphoneAndSystemAudio: "Microphone + app audio"
        }
    }
}
