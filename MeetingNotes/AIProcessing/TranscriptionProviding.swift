import Foundation

enum AIProcessingError: LocalizedError {
    case invalidResponse
    case emptyTranscript
    case audioFileUnavailable
    case openAIError(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "OpenAI returned an unexpected response."
        case .emptyTranscript:
            return "The transcript is empty."
        case .audioFileUnavailable:
            return "The audio file is missing or empty."
        case .openAIError(let message):
            return message
        }
    }
}
