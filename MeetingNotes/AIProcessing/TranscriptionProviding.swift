import Foundation

enum AIProcessingError: LocalizedError {
    case invalidResponse
    case emptyTranscript
    case audioFileUnavailable
    case backendError(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The backend returned an unexpected response."
        case .emptyTranscript:
            return "The transcript is empty."
        case .audioFileUnavailable:
            return "The audio file is missing or empty."
        case .backendError(let message):
            return message
        }
    }
}
