import Foundation
import Security

enum SessionStoreError: LocalizedError {
    case keychainFailure(OSStatus)
    case encodingFailure
    case decodingFailure

    var errorDescription: String? {
        switch self {
        case .keychainFailure(let status):
            return "Keychain error: \(status)"
        case .encodingFailure:
            return "Unable to save the current session."
        case .decodingFailure:
            return "Unable to restore the saved session."
        }
    }
}

final class SessionStore: @unchecked Sendable {
    static let shared = SessionStore()

    private let service = "MeetingNotes.Session"
    private let account = "USER_SESSION"
    private let lock = NSLock()
    private var cachedSession: UserSession?

    private init() {}

    func currentSession() -> UserSession? {
        lock.lock()
        if let cachedSession {
            lock.unlock()
            return cachedSession
        }
        lock.unlock()

        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        guard let session = try? JSONDecoder().decode(UserSession.self, from: data) else {
            return nil
        }

        lock.lock()
        cachedSession = session
        lock.unlock()
        return session
    }

    func save(_ session: UserSession) throws {
        guard let data = try? JSONEncoder().encode(session) else {
            throw SessionStoreError.encodingFailure
        }

        SecItemDelete(baseQuery() as CFDictionary)

        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SessionStoreError.keychainFailure(status)
        }

        lock.lock()
        cachedSession = session
        lock.unlock()
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SessionStoreError.keychainFailure(status)
        }

        lock.lock()
        cachedSession = nil
        lock.unlock()
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
