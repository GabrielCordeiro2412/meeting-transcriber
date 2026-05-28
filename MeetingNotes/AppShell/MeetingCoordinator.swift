import AppKit
import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class MeetingCoordinator: ObservableObject {
    @Published var recordingState: RecordingState = .idle {
        didSet { syncFloatingWidgetLayout() }
    }
    @Published var statusMessage = "Add your OpenAI API key to start recording"
    @Published var sessions: [MeetingSession] = []
    @Published var selectedSession: MeetingSession?
    @Published var isFloatingWidgetVisible = false
    @Published var recordingStartedAt: Date?
    @Published var accumulatedRecordingDuration: TimeInterval = 0
    @Published var inputLevel: Float = 0
    @Published var completionMessage: String?
    @Published var menuBarScreen: MenuBarScreen = .main
    @Published var summaryLanguagePreference: SummaryLanguagePreference

    private let store: MeetingSessionStore
    private var captureManager: AudioCaptureManaging
    private let meetingService: MeetingProcessingService
    private let apiKeyStore: APIKeyStore
    private let summaryLanguageStore: SummaryLanguageStore
    private let floatingWidgetController = FloatingWidgetController()
    private let historyWindowController = HistoryWindowController()
    private var activeSessionID: UUID?
    private var microphoneSegmentPaths: [String] = []
    private var systemSegmentPaths: [String] = []
    private var currentSegmentIndex = 0
    private let emptyAppAudioWarning = "App audio transcription failed: The transcript is empty."
    private let chunkProcessor = AudioChunkProcessor.shared

    init(
        store: MeetingSessionStore,
        captureManager: AudioCaptureManaging = CompositeAudioCaptureManager(),
        meetingService: MeetingProcessingService = OpenAIClient(),
        apiKeyStore: APIKeyStore = .shared,
        summaryLanguageStore: SummaryLanguageStore = .shared
    ) {
        self.store = store
        self.captureManager = captureManager
        self.meetingService = meetingService
        self.apiKeyStore = apiKeyStore
        self.summaryLanguageStore = summaryLanguageStore
        self.summaryLanguagePreference = summaryLanguageStore.current()
        self.captureManager.inputLevelHandler = { [weak self] level in
            Task { @MainActor in
                self?.inputLevel = level
            }
        }

        loadLocalHistory()
        normalizeInterruptedSessions()
        updateReadyStatus()
    }

    var hasAPIKey: Bool {
        guard let apiKey = apiKeyStore.currentAPIKey() else {
            return false
        }
        return APIKeyStore.isValidFormat(apiKey)
    }

    var currentAPIKey: String {
        apiKeyStore.currentAPIKey() ?? ""
    }

    var canStartRecording: Bool {
        hasAPIKey && (recordingState == .idle || recordingState == .completed || recordingState == .error)
    }

    var canStopRecording: Bool {
        recordingState == .recording
    }

    var canPauseRecording: Bool {
        recordingState == .recording
    }

    var canResumeRecording: Bool {
        recordingState == .paused
    }

    var canFinishRecording: Bool {
        hasAPIKey && (recordingState == .recording || recordingState == .paused)
    }

    var canDiscardRecording: Bool {
        recordingState == .recording || recordingState == .paused || recordingState == .requestingPermissions
    }

    var latestSession: MeetingSession? {
        sessions.first
    }

    var completedSessionsCount: Int {
        sessions.filter { $0.status == .completed }.count
    }

    var statusAccentLabel: String {
        if !hasAPIKey {
            return "Set API Key"
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
            return "Transcribing"
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

    func showAPIKeySettings() {
        menuBarScreen = .apiKey
    }

    func dismissAPIKeySettings() {
        menuBarScreen = .main
    }

    func showSummaryLanguageSettings() {
        menuBarScreen = .summaryLanguage
    }

    func dismissSummaryLanguageSettings() {
        menuBarScreen = .main
    }

    func setSummaryLanguagePreference(_ preference: SummaryLanguagePreference) {
        summaryLanguagePreference = preference
        summaryLanguageStore.save(preference)
    }

    func saveAPIKey(_ apiKey: String) {
        do {
            try apiKeyStore.save(apiKey)
            updateReadyStatus(message: "OpenAI API key saved.")
            objectWillChange.send()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func clearAPIKey() {
        apiKeyStore.clear()
        completionMessage = nil
        if recordingState != .recording && recordingState != .paused && recordingState != .processingTranscript && recordingState != .generatingSummary {
            recordingState = .idle
        }
        statusMessage = "OpenAI API key removed. Add a new key to process meetings."
        objectWillChange.send()
    }

    func startRecording() async {
        guard hasAPIKey else {
            statusMessage = "Add a valid OpenAI API key before recording."
            showAPIKeySettings()
            return
        }

        guard canStartRecording else {
            updateReadyStatus()
            return
        }
        completionMessage = nil

        do {
            recordingState = .requestingPermissions
            statusMessage = "Checking microphone and capture permissions"

            let session = try store.createSession(title: defaultTitle())
            session.startedAt = Date()
            session.status = .requestingPermissions
            session.syncState = .localOnly
            session.processingError = nil
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
                try? store.save()
            }
            loadLocalHistory()
        }
    }

    func finishRecording() async {
        guard hasAPIKey else {
            statusMessage = "Add a valid OpenAI API key before transcribing."
            showAPIKeySettings()
            return
        }

        guard canFinishRecording, let activeSessionID else {
            updateReadyStatus()
            return
        }
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

            guard let session = try store.session(id: activeSessionID) else {
                throw AIProcessingError.invalidResponse
            }

            session.endedAt = Date()
            session.audioFileURL = joinedPaths(microphoneSegmentPaths)
            session.systemAudioFileURL = joinedPaths(systemSegmentPaths)
            try store.save()
            selectedSession = session

            try await processSession(session)
        } catch {
            if let session = try? store.session(id: activeSessionID) {
                session.status = .error
                session.processingError = error.localizedDescription
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
                pathsToDelete.append(contentsOf: session.audioChunks.compactMap { $0.compressedFileURL ?? $0.localFileURL })
                try? store.deleteMeetingSession(sessionId: sessionID)
            }

            deleteFiles(at: pathsToDelete)
            selectedSession = nil
            resetForNextRecording()
            loadLocalHistory()
        }
    }

    func fetchMeetingHistory() {
        loadLocalHistory()
    }

    func retryProcessingSelectedSession() {
        guard hasAPIKey else {
            statusMessage = "Add a valid OpenAI API key before reprocessing."
            showAPIKeySettings()
            return
        }
        guard let session = selectedSession else { return }
        Task {
            await reprocess(session: session)
        }
    }

    func retryUploadSelectedSession() {
        retryProcessingSelectedSession()
    }

    func resetCompletionState() {
        completionMessage = nil
        recordingState = .idle
        updateReadyStatus()
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
        } catch {
            recordingState = .error
            statusMessage = error.localizedDescription
        }
    }

    func deleteMeetingSession(sessionId: UUID) {
        do {
            if let session = try store.session(id: sessionId) {
                let paths = storedPaths(from: session.audioFileURL)
                    + storedPaths(from: session.systemAudioFileURL)
                    + session.audioChunks.compactMap { $0.compressedFileURL ?? $0.localFileURL }
                deleteFiles(at: paths)
            }

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

    private func normalizeInterruptedSessions() {
        do {
            let history = try store.fetchMeetingHistory()
            var didChange = false
            for session in history where [.recording, .paused, .processingTranscript, .generatingSummary, .requestingPermissions].contains(session.status) {
                session.status = .error
                if session.processingError == nil || session.processingError?.isEmpty == true {
                    session.processingError = "Processing was interrupted. Reprocess this meeting to continue."
                }
                didChange = true
            }

            if didChange {
                try store.save()
                loadLocalHistory()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func processSession(_ session: MeetingSession) async throws {
        guard hasAPIKey else {
            throw OpenAIClientError.missingAPIKey
        }

        recordingState = .processingTranscript
        statusMessage = "Preparing audio"
        recordingStartedAt = nil
        inputLevel = 0

        let chunks = try await ensurePreparedChunks(for: session)
        session.audioChunks = chunks.map(\.chunk)
        session.status = .processingTranscript
        session.processingError = nil
        try store.save()

        var transcriptParts: [TranscriptPart] = []
        var hadEmptyChunks = false

        for (index, preparedChunk) in chunks.enumerated() {
            statusMessage = "Transcribing \(index + 1)/\(chunks.count)"
            var localChunk = preparedChunk.chunk
            localChunk.processingError = nil
            updateLocalChunk(localChunk, in: session)
            try store.save()

            let transcript = try await meetingService.transcribeAudio(fileURL: preparedChunk.uploadFileURL)
            let normalized = cleanedTranscript(transcript)

            if normalized.isEmpty {
                localChunk.transcriptionStatus = .empty
                localChunk.transcriptText = ""
                hadEmptyChunks = true
            } else {
                localChunk.transcriptionStatus = .completed
                localChunk.transcriptText = normalized
                transcriptParts.append(
                    TranscriptPart(
                        source: localChunk.source,
                        sequenceIndex: localChunk.sequenceIndex,
                        text: normalized
                    )
                )
            }

            updateLocalChunk(localChunk, in: session)
            try store.save()
        }

        let transcript = consolidateTranscript(transcriptParts)
        guard !transcript.isEmpty else {
            throw AIProcessingError.emptyTranscript
        }

        session.transcriptText = transcript
        session.status = .generatingSummary
        session.processingError = hadEmptyChunks ? "One or more chunks did not produce transcript text." : nil
        try store.save()

        recordingState = .generatingSummary
        statusMessage = "Generating summary (\(summaryLanguagePreference.shortLabel))"

        session.summaryLanguageRawValue = summaryLanguagePreference.rawValue
        try store.save()

        let summary = try await meetingService.summarizeTranscript(
            transcript,
            language: summaryLanguagePreference
        )
        session.apply(summary: summary)
        session.status = .completed
        try store.save()

        selectedSession = session
        postCompletionNotification(for: session)
        completionMessage = "Summary ready: \(session.title)"
        resetForNextRecording()
        statusMessage = "Summary ready to review"
        loadLocalHistory()
    }

    private func ensurePreparedChunks(for session: MeetingSession) async throws -> [PreparedAudioChunk] {
        let existing = session.audioChunks
        if !existing.isEmpty {
            let prepared = existing.compactMap { chunk -> PreparedAudioChunk? in
                guard let uploadPath = chunk.compressedFileURL ?? chunk.localFileURL else { return nil }
                let uploadURL = fileURL(from: uploadPath)
                guard isUsableAudioFile(uploadURL) else { return nil }
                return PreparedAudioChunk(chunk: chunk, uploadFileURL: uploadURL)
            }

            if prepared.count == existing.count {
                return prepared
            }

            session.audioChunks = []
            try store.save()
        }

        let recoveredRecordingPaths = recoveredRecordingPaths(for: session)
        let microphonePaths = storedPaths(from: session.audioFileURL).ifEmpty(use: recoveredRecordingPaths.microphone)
        let systemPaths = storedPaths(from: session.systemAudioFileURL).ifEmpty(use: recoveredRecordingPaths.system)

        if session.audioFileURL == nil, !microphonePaths.isEmpty {
            session.audioFileURL = joinedPaths(microphonePaths)
        }

        if session.systemAudioFileURL == nil, !systemPaths.isEmpty {
            session.systemAudioFileURL = joinedPaths(systemPaths)
        }

        let microphoneURLs = microphonePaths.map(fileURL(from:))
        let systemURLs = systemPaths.map(fileURL(from:))

        let microphoneChunks = try await chunkProcessor.prepareChunks(
            meetingID: session.id,
            source: .microphone,
            sourceURLs: microphoneURLs
        )
        let systemChunks = try await chunkProcessor.prepareChunks(
            meetingID: session.id,
            source: .system,
            sourceURLs: systemURLs
        )

        let prepared = microphoneChunks + systemChunks
        session.audioChunks = prepared.map(\.chunk)
        try store.save()
        return prepared
    }

    private func isUsableAudioFile(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let size = (try? url.resourceValues(forKeys: Set([URLResourceKey.fileSizeKey])).fileSize) ?? 0
        return size > 44
    }

    private func updateLocalChunk(_ chunk: MeetingAudioChunk, in session: MeetingSession) {
        var chunks = session.audioChunks
        if let index = chunks.firstIndex(where: { $0.id == chunk.id }) {
            chunks[index] = chunk
        } else {
            chunks.append(chunk)
        }
        session.audioChunks = chunks.sorted {
            if $0.source == $1.source {
                return $0.sequenceIndex < $1.sequenceIndex
            }
            return $0.source.rawValue < $1.source.rawValue
        }
    }

    private func reprocess(session: MeetingSession) async {
        do {
            try await processSession(session)
        } catch {
            session.status = .error
            session.processingError = error.localizedDescription
            try? store.save()
            loadLocalHistory()
            statusMessage = error.localizedDescription
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
            updateReadyStatus()
        }
    }

    private func updateReadyStatus(message: String? = nil) {
        if let message {
            statusMessage = message
            return
        }

        statusMessage = hasAPIKey
            ? "Ready to record"
            : "Add your OpenAI API key to start recording"
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

    private func recoveredRecordingPaths(for session: MeetingSession) -> (microphone: [String], system: [String]) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appending(path: "MeetingNotes/Recordings", directoryHint: .isDirectory)
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return ([], [])
        }

        let sessionPrefix = "\(session.id.uuidString.uppercased())-segment-"
        let matching = fileURLs.filter {
            $0.lastPathComponent.uppercased().hasPrefix(sessionPrefix)
        }

        let microphone = matching
            .filter { $0.lastPathComponent.contains("-microphone.") }
            .sorted(by: compareRecordingURL)
            .map(\.path)

        let system = matching
            .filter { $0.lastPathComponent.contains("-system.") }
            .sorted(by: compareRecordingURL)
            .map(\.path)

        return (microphone, system)
    }

    private func compareRecordingURL(_ lhs: URL, _ rhs: URL) -> Bool {
        segmentIndex(from: lhs) < segmentIndex(from: rhs)
    }

    private func segmentIndex(from url: URL) -> Int {
        let filename = url.deletingPathExtension().lastPathComponent
        guard let range = filename.range(of: "-segment-") else { return 0 }
        let suffix = filename[range.upperBound...]
        let number = suffix.split(separator: "-").first.flatMap { Int($0) }
        return number ?? 0
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

    private func consolidateTranscript(_ parts: [TranscriptPart]) -> String {
        let normalized = parts
            .map { part in
                TranscriptPart(
                    source: part.source,
                    sequenceIndex: part.sequenceIndex,
                    text: cleanedTranscript(part.text)
                )
            }
            .filter { !$0.text.isEmpty }
            .sorted {
                if $0.source == $1.source {
                    return $0.sequenceIndex < $1.sequenceIndex
                }
                return $0.source.rawValue < $1.source.rawValue
            }

        var deduplicated: [TranscriptPart] = []
        for part in normalized {
            if deduplicated.last?.text == part.text {
                continue
            }
            deduplicated.append(part)
        }

        return deduplicated.map(\.text).joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
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

enum MenuBarScreen {
    case main
    case apiKey
    case summaryLanguage
}

private struct TranscriptPart {
    let source: MeetingAudioChunk.Source
    let sequenceIndex: Int
    let text: String
}

private extension Array {
    func ifEmpty(use fallback: [Element]) -> [Element] {
        isEmpty ? fallback : self
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

