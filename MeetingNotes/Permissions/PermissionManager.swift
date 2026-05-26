import AVFoundation
import Foundation
import ScreenCaptureKit

enum PermissionError: LocalizedError {
    case microphoneDenied
    case screenCaptureUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Microphone permission was denied."
        case .screenCaptureUnavailable(let reason):
            "Screen/audio capture is unavailable: \(reason)"
        }
    }
}

final class PermissionManager: @unchecked Sendable {
    func requestMicrophonePermission() async throws {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        guard granted else { throw PermissionError.microphoneDenied }
    }

    func validateScreenCapturePermission() async throws {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            throw PermissionError.screenCaptureUnavailable(error.localizedDescription)
        }
    }
}
