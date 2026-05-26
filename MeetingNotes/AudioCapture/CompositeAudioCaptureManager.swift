import Foundation

@MainActor
final class CompositeAudioCaptureManager: AudioCaptureManaging {
    private let permissionManager: PermissionManager
    private let microphoneRecorder = MicrophoneRecorder()
    private let systemAudioRecorder = SystemAudioRecorder()
    private var microphoneURL: URL?
    private var systemAudioURL: URL?
    private var activeCaptureMode: CaptureMode = .microphoneOnly
    private var warnings: [String] = []
    var inputLevelHandler: (@Sendable (Float) -> Void)? {
        get { microphoneRecorder.levelHandler }
        set { microphoneRecorder.levelHandler = newValue }
    }

    init(permissionManager: PermissionManager = PermissionManager()) {
        self.permissionManager = permissionManager
    }

    func startRecording(sessionID: UUID, segmentIndex: Int) async throws -> AudioCaptureStartResult {
        warnings = []
        activeCaptureMode = .microphoneOnly

        try await permissionManager.requestMicrophonePermission()

        let directory = try recordingsDirectory()
        let micURL = directory.appending(path: "\(sessionID.uuidString)-segment-\(segmentIndex)-microphone.wav")
        let systemURL = directory.appending(path: "\(sessionID.uuidString)-segment-\(segmentIndex)-system.m4a")

        try microphoneRecorder.start(outputURL: micURL)
        microphoneURL = micURL

        do {
            try await permissionManager.validateScreenCapturePermission()
            try await systemAudioRecorder.start(outputURL: systemURL)
            systemAudioURL = systemURL
            activeCaptureMode = .microphoneAndSystemAudio
        } catch {
            warnings.append(error.localizedDescription)
            warnings.append("Continuing with microphone-only capture.")
            systemAudioURL = nil
            activeCaptureMode = .microphoneOnly
        }

        return AudioCaptureStartResult(captureMode: activeCaptureMode, warnings: warnings)
    }

    func stopRecording() async throws -> AudioCaptureResult {
        microphoneRecorder.stop()
        await systemAudioRecorder.stop()

        let result = AudioCaptureResult(
            microphoneAudioURL: microphoneURL,
            systemAudioURL: systemAudioURL,
            captureMode: activeCaptureMode,
            warnings: warnings
        )
        microphoneURL = nil
        systemAudioURL = nil
        warnings = []
        return result
    }

    private func recordingsDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appending(path: "MeetingNotes/Recordings", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
