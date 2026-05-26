import Foundation

struct UserSession: Codable, Equatable, Sendable {
    var userID: String
    var email: String
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date

    var isExpired: Bool {
        expiresAt <= Date()
    }
}
