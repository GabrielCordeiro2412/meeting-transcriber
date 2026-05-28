import Foundation
import Security

enum APIKeyStoreError: LocalizedError {
    case keychainFailure(OSStatus)
    case encodingFailure
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .keychainFailure(let status):
            return "Keychain error: \(status)"
        case .encodingFailure:
            return "Unable to save the OpenAI API key."
        case .invalidFormat:
            return "Enter a valid OpenAI API key (starts with sk-)."
        }
    }
}

final class APIKeyStore: @unchecked Sendable {
    static let shared = APIKeyStore()

    private let servicePrefix = "MeetingNotes.OpenAI.local"
    private let account = "OPENAI_API_KEY"
    private let suppressionDefaultsKey = "MeetingNotes.OpenAI.KeySuppressed"
    private let serviceIdentifierDefaultsKey = "MeetingNotes.OpenAI.ServiceIdentifier"
    private let lock = NSLock()
    private var cachedAPIKey: String?
    private var cacheSuppressed = false
    private var cacheLoaded = false

    private init() {}

    static func isValidFormat(_ apiKey: String) -> Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 20 else { return false }
        return trimmed.hasPrefix("sk-")
    }

    func currentAPIKey() -> String? {
        lock.lock()
        if cacheLoaded {
            let suppressed = cacheSuppressed
            let cached = cachedAPIKey
            lock.unlock()
            if suppressed { return nil }
            if let cached { return cached.isEmpty ? nil : cached }
        } else {
            lock.unlock()
        }

        if UserDefaults.standard.bool(forKey: suppressionDefaultsKey) {
            lock.lock()
            cacheLoaded = true
            cacheSuppressed = true
            cachedAPIKey = nil
            lock.unlock()
            return nil
        }

        guard let apiKey = readKeychainValue(), !apiKey.isEmpty else {
            lock.lock()
            cacheLoaded = true
            cacheSuppressed = false
            cachedAPIKey = nil
            lock.unlock()
            return nil
        }

        lock.lock()
        cacheLoaded = true
        cacheSuppressed = false
        cachedAPIKey = apiKey
        lock.unlock()
        return apiKey
    }

    func save(_ apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidFormat(trimmed) else {
            throw APIKeyStoreError.invalidFormat
        }
        guard let data = trimmed.data(using: .utf8) else {
            throw APIKeyStoreError.encodingFailure
        }

        do {
            try writeKeychainValue(data, service: activeService())
        } catch APIKeyStoreError.keychainFailure(let status) where status == errSecInvalidOwnerEdit || status == errSecDuplicateItem {
            try writeKeychainValue(data, service: rotateServiceIdentifier())
        }
        UserDefaults.standard.set(false, forKey: suppressionDefaultsKey)
        setCache(apiKey: trimmed, suppressed: false)
    }

    func clear() {
        UserDefaults.standard.set(true, forKey: suppressionDefaultsKey)
        setCache(apiKey: nil, suppressed: true)
        clearStoredKeychainValue(service: activeService())
        _ = rotateServiceIdentifier()
    }

    private func setCache(apiKey: String?, suppressed: Bool) {
        lock.lock()
        cachedAPIKey = apiKey
        cacheSuppressed = suppressed
        cacheLoaded = true
        lock.unlock()
    }

    private func readKeychainValue() -> String? {
        var query = identityQuery(service: activeService())
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        return apiKey
    }

    private func writeKeychainValue(_ data: Data, service: String) throws {
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        var status = SecItemUpdate(identityQuery(service: service) as CFDictionary, updateAttributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = identityQuery(service: service)
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        if status == errSecDuplicateItem {
            status = SecItemUpdate(identityQuery(service: service) as CFDictionary, updateAttributes as CFDictionary)
        }

        guard status == errSecSuccess else {
            throw APIKeyStoreError.keychainFailure(status)
        }
    }

    private func clearStoredKeychainValue(service: String) {
        // The old file-based macOS keychain can return errSecInvalidOwnerEdit (-25244)
        // after local app renames/moves. Clearing is best-effort, then the app rotates
        // to a fresh service name and ignores any orphaned item.
        let emptyData = Data()
        let updateAttributes: [String: Any] = [
            kSecValueData as String: emptyData,
        ]

        _ = SecItemUpdate(identityQuery(service: service) as CFDictionary, updateAttributes as CFDictionary)
    }

    private func activeService() -> String {
        if let identifier = UserDefaults.standard.string(forKey: serviceIdentifierDefaultsKey), !identifier.isEmpty {
            return "\(servicePrefix).\(identifier)"
        }

        return rotateServiceIdentifier()
    }

    private func rotateServiceIdentifier() -> String {
        let identifier = UUID().uuidString
        UserDefaults.standard.set(identifier, forKey: serviceIdentifierDefaultsKey)
        return "\(servicePrefix).\(identifier)"
    }

    private func identityQuery(service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
