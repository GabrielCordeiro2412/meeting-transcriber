import Foundation

struct AudioCaptureStartResult {
    var captureMode: CaptureMode
    var warnings: [String]
}

struct AudioCaptureResult {
    var microphoneAudioURL: URL?
    var systemAudioURL: URL?
    var captureMode: CaptureMode
    var warnings: [String]
}

@MainActor
protocol AudioCaptureManaging {
    var inputLevelHandler: (@Sendable (Float) -> Void)? { get set }
    func startRecording(sessionID: UUID, segmentIndex: Int) async throws -> AudioCaptureStartResult
    func stopRecording() async throws -> AudioCaptureResult
}
