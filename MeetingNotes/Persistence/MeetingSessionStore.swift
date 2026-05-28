import Foundation
import SwiftData

@MainActor
protocol MeetingSessionStore {
    func createSession(id: UUID, title: String) throws -> MeetingSession
    func createSession(title: String) throws -> MeetingSession
    func fetchMeetingHistory() throws -> [MeetingSession]
    func session(id: UUID) throws -> MeetingSession?
    func save() throws
    func deleteMeetingSession(sessionId: UUID) throws
}

@MainActor
final class SwiftDataMeetingSessionStore: MeetingSessionStore {
    private let modelContainer: ModelContainer
    private var context: ModelContext { modelContainer.mainContext }

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func createSession(title: String) throws -> MeetingSession {
        let session = MeetingSession(title: title, status: .idle)
        context.insert(session)
        try context.save()
        return session
    }

    func createSession(id: UUID, title: String) throws -> MeetingSession {
        let session = MeetingSession(id: id, title: title, status: .idle)
        context.insert(session)
        try context.save()
        return session
    }

    func fetchMeetingHistory() throws -> [MeetingSession] {
        let descriptor = FetchDescriptor<MeetingSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func session(id: UUID) throws -> MeetingSession? {
        let descriptor = FetchDescriptor<MeetingSession>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    func save() throws {
        try context.save()
    }

    func deleteMeetingSession(sessionId: UUID) throws {
        guard let session = try session(id: sessionId) else { return }
        context.delete(session)
        try context.save()
    }
}
