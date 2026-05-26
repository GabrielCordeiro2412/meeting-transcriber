import AppKit
import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class MeetingCoordinator: ObservableObject {
    @Published var recordingState: RecordingState = .idle {
        didSet { syncFloatingWidgetLayout() }
    }
    @Published var statusMessage = "Sign in to start recording"
    @Published var sessions: [MeetingSession] = []
    @Published var selectedSession: MeetingSession?
    @Published var isFloatingWidgetVisible = false
    @Published var recordingStartedAt: Date?
    @Published var accumulatedRecordingDuration: TimeInterval = 0
    @Published var inputLevel: Float = 0
    @Published var completionMessage: String?
    @Published var userSession: UserSession?
    @Published var isAuthenticating = false

    private let store: MeetingSessionStore
    private var captureManager: AudioCaptureManaging
    private let meetingService: MeetingProcessingService
    private let sessionStore: SessionStore
    private let floatingWidgetController = FloatingWidgetController()
    private let historyWindowController = HistoryWindowController()
    private var activeSessionID: UUID?
    private var microphoneSegmentPaths: [String] = []
    private var systemSegmentPaths: [String] = []
    private var currentSegmentIndex = 0
    private let emptyAppAudioWarning = "App audio transcription failed: The transcript is empty."

    init(
        store: MeetingSessionStore,
        captureManager: AudioCaptureManaging = CompositeAudioCaptureManager(),
        meetingService: MeetingProcessingService = BackendClient(),
        sessionStore: SessionStore = .shared
    ) {
        self.store = store
        self.captureManager = captureManager
        self.meetingService = meetingService
        self.sessionStore = sessionStore
        self.captureManager.inputLevelHandler = { [weak self] level in
            Task { @MainActor in
                self?.inputLevel = level
            }
        }

        loadLocalHistory()
        restoreSession()
    }

    var isAuthenticated: Bool {
        userSession != nil
    }

    var canStartRecording: Bool {
        isAuthenticated && (recordingState == .idle || recordingState == .completed || recordingState == .error)
    }

    var canStopRecording: Bool {
        isAuthenticated && recordingState == .recording
    }

    var canPauseRecording: Bool {
        isAuthenticated && recordingState == .recording
    }

    var canResumeRecording: Bool {
        isAuthenticated && recordingState == .paused
    }

    var canFinishRecording: Bool {
        isAuthenticated && (recordingState == .recording || recordingState == .paused)
    }

    var canDiscardRecording: Bool {
        isAuthenticated && (recordingState == .recording || recordingState == .paused || recordingState == .requestingPermissions)
    }

    var latestSession: MeetingSession? {
        sessions.first
    }

    var completedSessionsCount: Int {
        sessions.filter { $0.status == .completed }.count
    }

    var statusAccentLabel: String {
        if !isAuthenticated {
            return "Sign In"
        }

        switch recordingState {
        case .idle:
            return "Standby"
        case .requestingPermissions:
            return "Unlocking Access"
        case .recording:
            return "Live Capture"
        case .paused:
            return "Paused"
        case .processingTranscript:
            return "Uploading"
        case .generatingSummary:
            return "Writing Notes"
        case .completed:
            return "Ready to Review"
        case .error:
            return "Needs Fix"
        }
    }

    var widgetSize: CGSize {
        if completionMessage != nil {
            return CGSize(width: 392, height: 104)
        }

        switch recordingState {
        case .recording, .paused:
            return CGSize(width: 430, height: 104)
        case .processingTranscript, .generatingSummary:
            return CGSize(width: 390, height: 104)
        default:
            return CGSize(width: 312, height: 104)
        }
    }

    var widgetCornerRadius: CGFloat {
        28
    }

    func sendMagicLink(email: String) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }

        isAuthenticating = true
        statusMessage = "Sending magic link to \(trimmedEmail)"

        do {
            try await meetingService.sendMagicLink(email: trimmedEmail)
            statusMessage = "Magic link sent. Open the email on this Mac to finish sign in."
        } catch {
            statusMessage = error.localizedDescription
        }

        isAuthenticating = false
    }

    func handleAuthenticationCallback(url: URL) async {
        isAuthenticating = true
        statusMessage = "Completing sign in"

        do {
            let callbackSession = try meetingService.session(fromAuthCallbackURL: url)
            let validatedSession = try await meetingService.fetchCurrentUser(session: callbackSession)
            try sessionStore.save(validatedSession)
            userSession = validatedSession
            statusMessage = "Signed in as \(validatedSession.email)"
            await refreshRemoteHistory()
        } catch {
            userSession = nil
            statusMessage = error.localizedDescription
        }

        isAuthenticating = false
    }

    func signOut() {
        try? sessionStore.clear()
        userSession = nil
        completionMessage = nil
        if isFloatingWidgetVisible {
            floatingWidgetController.hide()
            isFloatingWidgetVisible = false
        }
        resetForNextRecording()
        statusMessage = "Signed out. Sign in to continue."
    }

    func startRecording() async {
        guard canStartRecording else { return }
        completionMessage = nil

        do {
            recordingState = .requestingPermissions
            statusMessage = "Checking microphone and capture permissions"

            let session = try store.createSession(title: defaultTitle())
            session.startedAt = Date()
            session.status = .requestingPermissions
            session.syncState = .localOnly
            try store.save()
            activeSessionID = session.id
            selectedSession = session
            recordingStartedAt = session.startedAt
            accumulatedRecordingDuration = 0
            currentSegmentIndex = 0
            microphoneSegmentPaths = []
            systemSegmentPaths = []

            let startResult = try await captureManager.startRecording(sessionID: session.id, segmentIndex: currentSegmentIndex)
            session.captureMode = startResult.captureMode
            session.status = .recording
            session.processingError = startResult.warnings.isEmpty ? nil : startResult.warnings.joined(separator: "\n")
            try store.save()

            recordingState = .recording
            statusMessage = startResult.captureMode == .microphoneAndSystemAudio
                ? "Recording microphone and app audio"
                : "Recording microphone only"
            inputLevel = 0
            loadLocalHistory()
        } catch {
            recordingState = .error
            statusMessage = error.localizedDescription
            inputLevel = 0
            selectedSession?.status = .error
            selectedSession?.processingError = error.localizedDescription
            try? store.save()
            loadLocalHistory()
        }
    }

    func pauseRecording() async {
        guard canPauseRecording, let activeSessionID else { return }
        completionMessage = nil

        do {
            statusMessage = "Pausing recording"

            let captureResult = try await captureManager.stopRecording()
            guard let session = try store.session(id: activeSessionID) else {
                throw AIProcessingError.invalidResponse
            }

            appendSegmentPaths(from: captureResult)
            accumulateCurrentSegmentDuration()
            session.captureMode = captureResult.captureMode
            session.audioFileURL = joinedPaths(microphoneSegmentPaths)
            session.systemAudioFileURL = joinedPaths(systemSegmentPaths)
            session.status = .paused
            if !captureResult.warnings.isEmpty {
                session.processingError = captureResult.warnings.joined(separator: "\n")
            }
            try store.save()
            selectedSession = session
            recordingStartedAt = nil
            recordingState = .paused
            statusMessage = "Recording paused"
            inputLevel = 0
            currentSegmentIndex += 1
            loadLocalHistory()
        } catch {
            recordingState = .error
            statusMessage = error.localizedDescription
            recordingStartedAt = nil
            inputLevel = 0
            if let session = selectedSession {
                session.status = .error
                session.processingError = error.localizedDescription
                session.syncState = .syncFailed
                try? store.save()
            }
            loadLocalHistory()
        }
    }

    func resumeRecording() async {
        guard canResumeRecording, let activeSessionID else { return }
        completionMessage = nil

        do {
            recordingState = .requestingPermissions
            statusMessage = "Resuming capture"
            let startResult = try await captureManager.startRecording(sessionID: activeSessionID, segmentIndex: currentSegmentIndex)
            guard let session = try store.session(id: activeSessionID) else {
                throw AIProcessingError.invalidResponse
            }

            session.captureMode = startResult.captureMode
            session.status = .recording
            session.processingError = mergedWarnings(existing: session.processingError, newWarnings: startResult.warnings)
            try store.save()

            recordingStartedAt = Date()
            recordingState = .recording
            statusMessage = startResult.captureMode == .microphoneAndSystemAudio
                ? "Recording microphone and app audio"
                : "Recording microphone only"
            inputLevel = 0
            selectedSession = session
            loadLocalHistory()
        } catch {
            recordingState = .error
            statusMessage = error.localizedDescription
            inputLevel = 0
            if let session = selectedSession {
                session.status = .error
                session.processingError = error.localizedDescription
                session.syncState = .syncFailed
                try? store.save()
            }
            loadLocalHistory()
        }
    }

    func finishRecording() async {
        guard canFinishRecording, let activeSessionID, let userSession else { return }
        completionMessage = nil

        do {
            if recordingState == .recording {
                statusMessage = "Finalizing recording"
                let captureResult = try await captureManager.stopRecording()
                appendSegmentPaths(from: captureResult)
                accumulateCurrentSegmentDuration()
                currentSegmentIndex += 1

                guard let session = try store.session(id: activeSessionID) else {
                    throw AIProcessingError.invalidResponse
                }

                session.captureMode = captureResult.captureMode
                session.audioFileURL = joinedPaths(microphoneSegmentPaths)
                session.systemAudioFileURL = joinedPaths(systemSegmentPaths)
                session.processingError = mergedWarnings(existing: session.processingError, newWarnings: captureResult.warnings)
                try store.save()
                selectedSession = session
            }

            recordingState = .processingTranscript
            statusMessage = "Uploading recording"
            recordingStartedAt = nil
            inputLevel = 0

            guard let session = try store.session(id: activeSessionID) else {
                throw AIProcessingError.invalidResponse
            }

            session.endedAt = Date()
            session.audioFileURL = joinedPaths(microphoneSegmentPaths)
            session.systemAudioFileURL = joinedPaths(systemSegmentPaths)
            session.status = .processingTranscript
            session.syncState = .localOnly
            try store.save()
            selectedSession = session

            let createPayload = CreateMeetingPayload(
                id: session.id,
                title: session.title,
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                captureMode: session.captureMode
            )
            try await meetingService.createMeeting(request: createPayload, userSession: userSession)
            try await uploadSessionAudio(session, userSession: userSession)

            statusMessage = "Generating transcript and summary"
            let remoteSession = try await meetingService.processMeeting(meetingID: session.id, userSession: userSession)

            session.apply(remote: remoteSession)
            session.syncState = .synced
            try store.save()

            selectedSession = session
            postCompletionNotification(for: session)
            completionMessage = "Summary ready: \(session.title)"
            resetForNextRecording()
            statusMessage = "Summary ready to review"
            await refreshRemoteHistory()
        } catch BackendClientError.unauthorized {
            if let session = try? store.session(id: activeSessionID) {
                session.status = .error
                session.processingError = BackendClientError.unauthorized.localizedDescription
                session.syncState = .syncFailed
                try? store.save()
            }
            signOut()
        } catch {
            if let session = try? store.session(id: activeSessionID) {
                session.status = .error
                session.processingError = error.localizedDescription
                session.syncState = .syncFailed
                try? store.save()
                selectedSession = session
            }
            resetForNextRecording()
            loadLocalHistory()
            statusMessage = error.localizedDescription
        }
    }

    func discardRecording() async {
        guard canDiscardRecording else { return }
        let sessionID = activeSessionID

        do {
            if recordingState == .recording || recordingState == .requestingPermissions {
                let captureResult = try? await captureManager.stopRecording()
                if let captureResult {
                    appendSegmentPaths(from: captureResult)
                }
            }

            var pathsToDelete = microphoneSegmentPaths + systemSegmentPaths
            if let sessionID, let session = try? store.session(id: sessionID) {
                pathsToDelete.append(contentsOf: storedPaths(from: session.audioFileURL))
                pathsToDelete.append(contentsOf: storedPaths(from: session.systemAudioFileURL))
                try? store.deleteMeetingSession(sessionId: sessionID)
            }

            deleteFiles(at: pathsToDelete)
            selectedSession = nil
            resetForNextRecording()
            loadLocalHistory()
        }
    }

    func fetchMeetingHistory() {
        Task { await refreshRemoteHistory() }
    }

    func resetCompletionState() {
        completionMessage = nil
        statusMessage = isAuthenticated ? "Ready to record" : "Sign in to start recording"
        recordingState = .idle
        syncFloatingWidgetLayout()
    }

    func saveSessionEdits(
        sessionId: UUID,
        title: String,
        summary: String,
        detailedNotes: [String],
        topics: [String],
        keyPoints: [String],
        decisions: [String],
        actionItems: [String],
        risksOrBlockers: [String],
        followUpItems: [String],
        openQuestions: [String],
        transcript: String
    ) {
        do {
            guard let session = try store.session(id: sessionId) else { return }
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTitle.isEmpty {
                session.title = trimmedTitle
            }
            session.summaryText = summary
            session.detailedNotes = detailedNotes
            session.topics = topics
            session.keyPoints = keyPoints
            session.decisions = decisions
            session.actionItems = actionItems
            session.risksOrBlockers = risksOrBlockers
            session.followUpItems = followUpItems
            session.openQuestions = openQuestions
            session.transcriptText = transcript
            try store.save()
            selectedSession = session
            statusMessage = "Meeting notes saved"
            loadLocalHistory()

            if session.syncState == .synced, let userSession {
                let payload = UpdateMeetingPayload(
                    title: session.title,
                    summaryText: session.summaryText,
                    transcriptText: session.transcriptText,
                    summaryPayload: MeetingSummaryResult(
                        title: session.title,
                        summary: session.summaryText,
                        detailedNotes: session.detailedNotes ?? [],
                        topics: session.topics ?? [],
                        keyPoints: session.keyPoints,
                        decisions: session.decisions,
                        actionItems: session.actionItems,
                        openQuestions: session.openQuestions,
                        risksOrBlockers: session.risksOrBlockers ?? [],
                        followUpItems: session.followUpItems ?? []
                    )
                )
                Task {
                    do {
                        _ = try await meetingService.updateMeeting(request: payload, meetingID: session.id, userSession: userSession)
                        await refreshRemoteHistory()
                    } catch {
                        await MainActor.run {
                            self.statusMessage = error.localizedDescription
                        }
                    }
                }
            }
        } catch {
            recordingState = .error
            statusMessage = error.localizedDescription
        }
    }

    func deleteMeetingSession(sessionId: UUID) {
        do {
            try store.deleteMeetingSession(sessionId: sessionId)
            if selectedSession?.id == sessionId {
                selectedSession = nil
            }
            loadLocalHistory()
        } catch {
            recordingState = .error
            statusMessage = error.localizedDescription
        }
    }

    func selectSession(_ session: MeetingSession?) {
        selectedSession = session
    }

    func toggleFloatingWidget() {
        guard isAuthenticated else {
            statusMessage = "Sign in before opening the recorder widget."
            return
        }

        if isFloatingWidgetVisible {
            floatingWidgetController.hide()
            isFloatingWidgetVisible = false
        } else {
            floatingWidgetController.show(coordinator: self)
            syncFloatingWidgetLayout()
            isFloatingWidgetVisible = true
        }
    }

    func prepareForAuxiliaryWindow() {
        NSApp.activate(ignoringOtherApps: true)
    }

    func revealAppInFinder() {
        prepareForAuxiliaryWindow()
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    func showHistoryWindow(sessionId: UUID? = nil) {
        loadLocalHistory()
        if let sessionId {
            selectSession(sessions.first { $0.id == sessionId })
        }
        prepareForAuxiliaryWindow()
        historyWindowController.show(coordinator: self)
    }

    func quitApp() {
        NSApp.terminate(nil)
    }

    private func restoreSession() {
        userSession = sessionStore.currentSession()
        if let session = userSession, !session.isExpired {
            statusMessage = "Restoring session"
            Task { await validateStoredSession() }
        } else {
            statusMessage = "Sign in to start recording"
        }
    }

    private func validateStoredSession() async {
        guard let existingSession = userSession else { return }
        do {
            let validated = try await meetingService.fetchCurrentUser(session: existingSession)
            try sessionStore.save(validated)
            userSession = validated
            statusMessage = "Signed in as \(validated.email)"
            await refreshRemoteHistory()
        } catch {
            signOut()
        }
    }

    private func refreshRemoteHistory() async {
        loadLocalHistory()
        guard let userSession else { return }
        do {
            let remoteSessions = try await meetingService.fetchMeetings(userSession: userSession)
            try store.upsertRemoteSessions(remoteSessions)
            loadLocalHistory()
            if statusMessage == "Restoring session" || statusMessage == "Signed in to start recording" {
                statusMessage = "Signed in as \(userSession.email)"
            }
        } catch BackendClientError.unauthorized {
            signOut()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func loadLocalHistory() {
        do {
            sessions = try store.fetchMeetingHistory()
            let didCleanWarnings = removeBenignAppAudioWarnings(from: sessions)
            let didCleanTranscriptArtifacts = removeTranscriptArtifacts(from: sessions)
            if didCleanWarnings || didCleanTranscriptArtifacts {
                try store.save()
                sessions = try store.fetchMeetingHistory()
            }
            if selectedSession == nil {
                selectedSession = sessions.first
            } else if let selectedID = selectedSession?.id {
                selectedSession = sessions.first(where: { $0.id == selectedID }) ?? sessions.first
            }
        } catch {
            recordingState = .error
            statusMessage = error.localizedDescription
            inputLevel = 0
        }
    }

    private func uploadSessionAudio(_ session: MeetingSession, userSession: UserSession) async throws {
        let microphoneURLs = storedPaths(from: session.audioFileURL).map(fileURL(from:))
        let systemURLs = storedPaths(from: session.systemAudioFileURL).map(fileURL(from:))

        if !microphoneURLs.isEmpty {
            try await meetingService.uploadAudio(meetingID: session.id, source: .microphone, fileURLs: microphoneURLs, userSession: userSession)
        }

        if !systemURLs.isEmpty {
            try await meetingService.uploadAudio(meetingID: session.id, source: .system, fileURLs: systemURLs, userSession: userSession)
        }
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Meeting \(formatter.string(from: Date()))"
    }

    private func fileURL(from storedPath: String) -> URL {
        let normalizedPath = storedPath.removingPercentEncoding ?? storedPath
        return URL(filePath: normalizedPath)
    }

    private func storedPaths(from value: String?) -> [String] {
        guard let value, !value.isEmpty else { return [] }
        return value
            .split(separator: "\n")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    private func joinedPaths(_ paths: [String]) -> String? {
        let filtered = paths.filter { !$0.isEmpty }
        guard !filtered.isEmpty else { return nil }
        return filtered.joined(separator: "\n")
    }

    private func appendSegmentPaths(from captureResult: AudioCaptureResult) {
        if let micPath = captureResult.microphoneAudioURL?.path {
            microphoneSegmentPaths.append(micPath)
        }
        if let systemPath = captureResult.systemAudioURL?.path {
            systemSegmentPaths.append(systemPath)
        }
    }

    private func accumulateCurrentSegmentDuration() {
        guard let recordingStartedAt else { return }
        accumulatedRecordingDuration += Date().timeIntervalSince(recordingStartedAt)
        self.recordingStartedAt = nil
    }

    private func mergedWarnings(existing: String?, newWarnings: [String]) -> String? {
        let warnings = ([existing].compactMap { $0 } + newWarnings).filter { !$0.isEmpty }
        guard !warnings.isEmpty else { return nil }
        return warnings.joined(separator: "\n")
    }

    private func resetForNextRecording() {
        activeSessionID = nil
        microphoneSegmentPaths = []
        systemSegmentPaths = []
        currentSegmentIndex = 0
        accumulatedRecordingDuration = 0
        recordingStartedAt = nil
        inputLevel = 0
        recordingState = .idle
        if completionMessage == nil {
            statusMessage = isAuthenticated ? "Ready to record" : "Sign in to start recording"
        }
    }

    private func syncFloatingWidgetLayout() {
        guard isFloatingWidgetVisible else { return }
        floatingWidgetController.updateLayout(size: widgetSize)
    }

    private func deleteFiles(at paths: [String]) {
        for path in Set(paths) where !path.isEmpty {
            try? FileManager.default.removeItem(at: fileURL(from: path))
        }
    }

    private func removeBenignAppAudioWarnings(from sessions: [MeetingSession]) -> Bool {
        var didChange = false
        for session in sessions where session.status == .completed {
            guard let processingError = session.processingError, !processingError.isEmpty else { continue }
            let remainingWarnings = processingError
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0 != emptyAppAudioWarning }

            if remainingWarnings.joined(separator: "\n") != processingError {
                session.processingError = remainingWarnings.isEmpty ? nil : remainingWarnings.joined(separator: "\n")
                didChange = true
            }
        }
        return didChange
    }

    private func removeTranscriptArtifacts(from sessions: [MeetingSession]) -> Bool {
        var didChange = false
        for session in sessions {
            let cleaned = cleanedTranscript(session.transcriptText)
            if cleaned != session.transcriptText {
                session.transcriptText = cleaned
                didChange = true
            }
        }
        return didChange
    }

    private func cleanedTranscript(_ transcript: String) -> String {
        transcript
            .components(separatedBy: "\n\n")
            .compactMap { block -> String? in
                let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.lowercased().contains("transcreva em português com pontuação clara") else {
                    return nil
                }

                return trimmed.replacingOccurrences(
                    of: #"^(Microphone|App audio) \d+:\n"#,
                    with: "",
                    options: .regularExpression
                )
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func postCompletionNotification(for session: MeetingSession) {
        let content = UNMutableNotificationContent()
        content.title = "Meeting notes ready"
        content.body = "Audio transcribed successfully for \(session.title)."
        content.sound = .default
        content.categoryIdentifier = MeetingNotificationManager.categoryIdentifier
        content.userInfo = ["sessionId": session.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "meeting-summary-\(session.id.uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

@MainActor
private final class HistoryWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(coordinator: MeetingCoordinator) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let rootView = MeetingHistoryView()
            .environmentObject(coordinator)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Meeting History"
        window.minSize = NSSize(width: 760, height: 520)
        window.collectionBehavior = [.fullScreenPrimary]
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: rootView)
        window.standardWindowButton(.zoomButton)?.isEnabled = true
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

enum MeetingNotificationManager {
    static let categoryIdentifier = "MEETING_SUMMARY_READY"
    static let openActionIdentifier = "OPEN_SUMMARY"
}
