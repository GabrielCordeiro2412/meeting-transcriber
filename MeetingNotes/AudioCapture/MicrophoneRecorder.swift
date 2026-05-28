import AVFoundation
import Foundation

final class MicrophoneRecorder {
    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private(set) var outputURL: URL?
    var levelHandler: (@Sendable (Float) -> Void)?

    func start(outputURL: URL) throws {
        self.outputURL = outputURL

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            do {
                try self.audioFile?.write(from: buffer)
                self.levelHandler?(self.normalizedLevel(from: buffer))
            } catch {
                NSLog("Microphone write failed: \(error.localizedDescription)")
            }
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        guard engine.isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        levelHandler?(0)
    }

    private func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard
            let channelData = buffer.floatChannelData?[0]
        else {
            return 0
        }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }

        var rms: Float = 0
        for index in 0..<frameCount {
            let sample = channelData[index]
            rms += sample * sample
        }

        rms = sqrt(rms / Float(frameCount))
        let scaled = min(max(rms * 14, 0), 1)
        return scaled
    }
}
