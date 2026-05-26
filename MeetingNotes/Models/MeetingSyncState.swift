import Foundation

enum MeetingSyncState: String, Codable, Sendable {
    case localOnly
    case synced
    case syncFailed
}
