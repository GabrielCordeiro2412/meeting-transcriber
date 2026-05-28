import Foundation

enum SummaryLanguagePreference: String, CaseIterable, Codable, Sendable {
    case sameAsTranscript
    case portuguese
    case english

    var title: String {
        switch self {
        case .sameAsTranscript:
            return "Same as transcript"
        case .portuguese:
            return "Portuguese"
        case .english:
            return "English"
        }
    }

    var shortLabel: String {
        switch self {
        case .sameAsTranscript:
            return "Auto"
        case .portuguese:
            return "PT"
        case .english:
            return "EN"
        }
    }

    var detail: String {
        switch self {
        case .sameAsTranscript:
            return "Notes follow the dominant language spoken in the meeting."
        case .portuguese:
            return "Notes are always written in Brazilian Portuguese."
        case .english:
            return "Notes are always written in English."
        }
    }

    func languageInstruction() -> String {
        switch self {
        case .sameAsTranscript:
            return "Write all output in the same language as the transcript."
        case .portuguese:
            return "Write all output in Brazilian Portuguese, even if the transcript is in another language."
        case .english:
            return "Write all output in English, even if the transcript is in another language."
        }
    }
}

final class SummaryLanguageStore: @unchecked Sendable {
    static let shared = SummaryLanguageStore()

    private let defaultsKey = "MeetingNotes.SummaryLanguagePreference"

    private init() {}

    func current() -> SummaryLanguagePreference {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
              let preference = SummaryLanguagePreference(rawValue: raw) else {
            return .sameAsTranscript
        }
        return preference
    }

    func save(_ preference: SummaryLanguagePreference) {
        UserDefaults.standard.set(preference.rawValue, forKey: defaultsKey)
    }
}
