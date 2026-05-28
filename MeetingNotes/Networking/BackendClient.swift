import Foundation

protocol MeetingProcessingService: Sendable {
    func transcribeAudio(fileURL: URL) async throws -> String
    func summarizeTranscript(
        _ transcript: String,
        language preference: SummaryLanguagePreference
    ) async throws -> MeetingSummaryResult
}

enum OpenAIClientError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case message(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your OpenAI API key before processing meetings."
        case .invalidResponse:
            return "OpenAI returned an unexpected response."
        case .message(let message):
            return message
        }
    }
}

final class OpenAIClient: @unchecked Sendable, MeetingProcessingService {
    private let apiKeyStore: APIKeyStore
    private let session: URLSession
    private let decoder: JSONDecoder

    private let transcriptionModel = "gpt-4o-mini-transcribe"
    private let summaryModel = "gpt-4.1-mini"
    private let transcriptionPrompt = "Transcribe with clear punctuation. Preserve proper names, technical terms, decisions, next steps, and questions discussed in the meeting. Return only the spoken content in the language being spoken."

    init(
        apiKeyStore: APIKeyStore = .shared,
        session: URLSession = .shared
    ) {
        self.apiKeyStore = apiKeyStore
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func transcribeAudio(fileURL: URL) async throws -> String {
        let apiKey = try requireAPIKey()

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        var form = MultipartFormData(boundary: boundary)
        form = form.appendField(name: "model", value: transcriptionModel)
        form = form.appendField(name: "response_format", value: "json")
        form = form.appendField(name: "prompt", value: transcriptionPrompt)
        form = form.appendFile(
            name: "file",
            filename: fileURL.lastPathComponent,
            mimeType: mimeType(for: fileURL),
            data: fileData
        )
        request.httpBody = form.finalize()

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let payload = try decoder.decode(TranscriptionResponse.self, from: data)
        return cleanTranscript(payload.text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func summarizeTranscript(
        _ transcript: String,
        language preference: SummaryLanguagePreference
    ) async throws -> MeetingSummaryResult {
        let apiKey = try requireAPIKey()

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let languageInstruction = preference.languageInstruction()
        let bodyObject: [String: Any] = [
            "model": summaryModel,
            "messages": [
                [
                    "role": "system",
                    "content": "You convert meeting transcripts into complete, practical meeting notes. \(languageInstruction) Be specific and preserve concrete details, decisions, tradeoffs, examples, numbers, blockers, and follow-up context. Return JSON that follows the provided schema exactly."
                ],
                [
                    "role": "user",
                    "content": transcript
                ]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "meeting_summary",
                    "strict": true,
                    "schema": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "title": ["type": "string"],
                            "summary": ["type": "string"],
                            "detailedNotes": ["type": "array", "items": ["type": "string"]],
                            "topics": ["type": "array", "items": ["type": "string"]],
                            "keyPoints": ["type": "array", "items": ["type": "string"]],
                            "decisions": ["type": "array", "items": ["type": "string"]],
                            "actionItems": ["type": "array", "items": ["type": "string"]],
                            "openQuestions": ["type": "array", "items": ["type": "string"]],
                            "risksOrBlockers": ["type": "array", "items": ["type": "string"]],
                            "followUpItems": ["type": "array", "items": ["type": "string"]],
                        ],
                        "required": [
                            "title",
                            "summary",
                            "detailedNotes",
                            "topics",
                            "keyPoints",
                            "decisions",
                            "actionItems",
                            "openQuestions",
                            "risksOrBlockers",
                            "followUpItems",
                        ],
                    ],
                ],
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: bodyObject)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let payload = try decoder.decode(ChatCompletionResponse.self, from: data)
        guard let content = payload.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            throw OpenAIClientError.invalidResponse
        }

        return try decoder.decode(MeetingSummaryResult.self, from: contentData)
    }

    private func requireAPIKey() throws -> String {
        guard let apiKey = apiKeyStore.currentAPIKey(),
              APIKeyStore.isValidFormat(apiKey) else {
            throw OpenAIClientError.missingAPIKey
        }
        return apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else {
            throw OpenAIClientError.invalidResponse
        }

        guard (200..<300).contains(response.statusCode) else {
            if let payload = try? decoder.decode(OpenAIErrorEnvelope.self, from: data) {
                let code = payload.error.code.map { " (\($0))" } ?? ""
                let requestID = response.value(forHTTPHeaderField: "x-request-id").map { " [request_id=\($0)]" } ?? ""
                throw OpenAIClientError.message("\(response.statusCode)\(code): \(payload.error.message)\(requestID)")
            }

            throw OpenAIClientError.invalidResponse
        }
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m4a":
            return "audio/mp4"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "webm":
            return "audio/webm"
        default:
            return "application/octet-stream"
        }
    }

    private func cleanTranscript(_ transcript: String) -> String {
        transcript
            .replacingOccurrences(of: #"context:\s*#{3}[\s\S]*?#{3}"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"Transcribe in Brazilian Portuguese with clear punctuation\.[^\n]*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"Transcreva em português brasileiro com pontuação clara\.[^\n]*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct TranscriptionResponse: Decodable {
    let text: String
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct OpenAIErrorEnvelope: Decodable {
    struct OpenAIError: Decodable {
        let message: String
        let code: String?
    }

    let error: OpenAIError
}

private struct MultipartFormData {
    private let boundary: String
    private var body = Data()

    init(boundary: String) {
        self.boundary = boundary
    }

    func appendFile(name: String, filename: String, mimeType: String, data: Data) -> MultipartFormData {
        var copy = self
        copy.body.append("--\(boundary)\r\n".data(using: .utf8)!)
        copy.body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        copy.body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        copy.body.append(data)
        copy.body.append("\r\n".data(using: .utf8)!)
        return copy
    }

    func appendField(name: String, value: String) -> MultipartFormData {
        var copy = self
        copy.body.append("--\(boundary)\r\n".data(using: .utf8)!)
        copy.body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        copy.body.append("\(value)\r\n".data(using: .utf8)!)
        return copy
    }

    func finalize() -> Data {
        var copy = body
        copy.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return copy
    }
}
