import Foundation

protocol MeetingProcessingService: Sendable {
    func sendMagicLink(email: String) async throws
    func session(fromAuthCallbackURL url: URL) throws -> UserSession
    func fetchCurrentUser(session: UserSession) async throws -> UserSession
    func createMeeting(request: CreateMeetingPayload, userSession: UserSession) async throws
    func uploadAudio(meetingID: UUID, source: RemoteUploadSource, fileURLs: [URL], userSession: UserSession) async throws
    func processMeeting(meetingID: UUID, userSession: UserSession) async throws -> RemoteMeetingSession
    func fetchMeetings(userSession: UserSession) async throws -> [RemoteMeetingSession]
    func fetchMeeting(meetingID: UUID, userSession: UserSession) async throws -> RemoteMeetingSession
    func updateMeeting(request: UpdateMeetingPayload, meetingID: UUID, userSession: UserSession) async throws -> RemoteMeetingSession
}

enum RemoteUploadSource: String {
    case microphone
    case system
}

enum BackendClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case authCallbackMissingTokens
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The backend URL is invalid."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .unauthorized:
            return "Your session expired. Sign in again to continue."
        case .authCallbackMissingTokens:
            return "The sign-in callback did not include a valid session."
        case .message(let message):
            return message
        }
    }
}

final class BackendClient: @unchecked Sendable, MeetingProcessingService {
    private let configuration: BackendConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        configuration: BackendConfiguration = .load(),
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func sendMagicLink(email: String) async throws {
        let payload = MagicLinkRequest(email: email, redirectURL: configuration.authRedirectURL)
        let request = try makeRequest(path: "/auth/magic-link", method: "POST", body: payload)
        let (_, response) = try await session.data(for: request)
        try validate(response: response, data: nil)
    }

    func fetchCurrentUser(session userSession: UserSession) async throws -> UserSession {
        let request = try authorizedRequest(path: "/auth/me", userSession: userSession)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let currentUser = try decoder.decode(CurrentUserResponse.self, from: data)
        return UserSession(
            userID: currentUser.userID,
            email: currentUser.email,
            accessToken: userSession.accessToken,
            refreshToken: userSession.refreshToken,
            expiresAt: userSession.expiresAt
        )
    }

    func createMeeting(request payload: CreateMeetingPayload, userSession: UserSession) async throws {
        let request = try authorizedRequest(path: "/meetings", method: "POST", body: payload, userSession: userSession)
        let (data, response) = try await self.session.data(for: request)
        try validate(response: response, data: data)
    }

    func uploadAudio(meetingID: UUID, source: RemoteUploadSource, fileURLs: [URL], userSession: UserSession) async throws {
        guard !fileURLs.isEmpty else { return }

        var request = try authorizedRequest(path: "/meetings/\(meetingID.uuidString)/upload?source=\(source.rawValue)", method: "POST", userSession: userSession)
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var form = MultipartFormData(boundary: boundary)
        for fileURL in fileURLs {
            let data = try Data(contentsOf: fileURL)
            form = form.appendFile(
                name: "files",
                filename: fileURL.lastPathComponent,
                mimeType: mimeType(for: fileURL),
                data: data
            )
        }
        request.httpBody = form.finalize()

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    func processMeeting(meetingID: UUID, userSession: UserSession) async throws -> RemoteMeetingSession {
        let request = try authorizedRequest(path: "/meetings/\(meetingID.uuidString)/process", method: "POST", userSession: userSession)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(RemoteMeetingSession.self, from: data)
    }

    func fetchMeetings(userSession: UserSession) async throws -> [RemoteMeetingSession] {
        let request = try authorizedRequest(path: "/meetings", userSession: userSession)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode([RemoteMeetingSession].self, from: data)
    }

    func fetchMeeting(meetingID: UUID, userSession: UserSession) async throws -> RemoteMeetingSession {
        let request = try authorizedRequest(path: "/meetings/\(meetingID.uuidString)", userSession: userSession)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(RemoteMeetingSession.self, from: data)
    }

    func updateMeeting(request payload: UpdateMeetingPayload, meetingID: UUID, userSession: UserSession) async throws -> RemoteMeetingSession {
        let request = try authorizedRequest(path: "/meetings/\(meetingID.uuidString)", method: "PATCH", body: payload, userSession: userSession)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(RemoteMeetingSession.self, from: data)
    }

    func session(fromAuthCallbackURL url: URL) throws -> UserSession {
        let parameters = url.queryParameters.merging(url.fragmentParameters) { current, _ in current }
        guard let accessToken = parameters["access_token"],
              let refreshToken = parameters["refresh_token"] else {
            throw BackendClientError.authCallbackMissingTokens
        }

        let userID = parameters["user_id"] ?? parameters["sub"] ?? ""
        let email = parameters["email"] ?? ""
        let expiresIn = TimeInterval(parameters["expires_in"] ?? "") ?? 3600
        return UserSession(
            userID: userID,
            email: email,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(expiresIn)
        )
    }

    private func makeRequest<T: Encodable>(path: String, method: String, body: T? = nil) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: configuration.apiBaseURL) else {
            throw BackendClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    private func authorizedRequest<T: Encodable>(
        path: String,
        method: String = "GET",
        body: T? = nil,
        userSession: UserSession
    ) throws -> URLRequest {
        var request = try makeRequest(path: path, method: method, body: body)
        request.setValue("Bearer \(userSession.accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func authorizedRequest(
        path: String,
        method: String = "GET",
        userSession: UserSession
    ) throws -> URLRequest {
        var request = try makeRequest(path: path, method: method, body: Optional<String>.none)
        request.setValue("Bearer \(userSession.accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validate(response: URLResponse, data: Data?) throws {
        guard let response = response as? HTTPURLResponse else {
            throw BackendClientError.invalidResponse
        }

        if response.statusCode == 401 {
            throw BackendClientError.unauthorized
        }

        guard (200..<300).contains(response.statusCode) else {
            if let data,
               let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw BackendClientError.message(errorResponse.error)
            }
            throw BackendClientError.invalidResponse
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
}

private struct MagicLinkRequest: Encodable {
    let email: String
    let redirectURL: String

    enum CodingKeys: String, CodingKey {
        case email
        case redirectURL = "redirectUrl"
    }
}

struct CreateMeetingPayload: Encodable, Sendable {
    let id: UUID
    let title: String
    let startedAt: Date?
    let endedAt: Date?
    let captureMode: CaptureMode
}

struct UpdateMeetingPayload: Encodable, Sendable {
    let title: String
    let summaryText: String
    let transcriptText: String
    let summaryPayload: MeetingSummaryResult
}

private struct CurrentUserResponse: Decodable {
    let userID: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case email
    }
}

private struct APIErrorResponse: Decodable {
    let error: String
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

    func finalize() -> Data {
        var copy = body
        copy.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return copy
    }
}

private extension URL {
    var queryParameters: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            return [:]
        }

        return items.reduce(into: [:]) { partialResult, item in
            if let value = item.value {
                partialResult[item.name] = value
            }
        }
    }

    var fragmentParameters: [String: String] {
        guard let fragment, !fragment.isEmpty else { return [:] }
        let cleaned = fragment.replacingOccurrences(of: "#", with: "")
        return cleaned
            .split(separator: "&")
            .reduce(into: [:]) { partialResult, pair in
                let components = pair.split(separator: "=", maxSplits: 1).map(String.init)
                guard components.count == 2 else { return }
                partialResult[components[0]] = components[1].removingPercentEncoding ?? components[1]
            }
    }
}
