import Foundation

struct BackendConfiguration {
    let apiBaseURL: URL
    let authRedirectURL: String

    static func load(bundle: Bundle = .main) -> BackendConfiguration {
        let environment = ProcessInfo.processInfo.environment

        let apiBaseURLString = environment["MEETING_NOTES_API_BASE_URL"]
            ?? bundle.object(forInfoDictionaryKey: "MeetingNotesAPIBaseURL") as? String
            ?? "http://127.0.0.1:8787"

        let authRedirectURL = environment["MEETING_NOTES_AUTH_REDIRECT_URL"]
            ?? bundle.object(forInfoDictionaryKey: "MeetingNotesAuthRedirectURL") as? String
            ?? "meetingnotes://auth/callback"

        return BackendConfiguration(
            apiBaseURL: URL(string: apiBaseURLString) ?? URL(string: "http://127.0.0.1:8787")!,
            authRedirectURL: authRedirectURL
        )
    }
}
