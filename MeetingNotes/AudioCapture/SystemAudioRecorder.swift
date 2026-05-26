import AVFoundation
import Foundation
import ScreenCaptureKit

final class SystemAudioRecorder: NSObject, @unchecked Sendable, SCStreamOutput, SCStreamDelegate {
    private let queue = DispatchQueue(label: "MeetingNotes.SystemAudioRecorder")
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var didStartSession = false
    private(set) var outputURL: URL?

    func start(outputURL: URL) async throws {
        self.outputURL = outputURL

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = content.displays.first else {
            throw PermissionError.screenCaptureUnavailable("No display is available for capture.")
        }

        let currentApplication = content.applications.first { application in
            application.bundleIdentifier == Bundle.main.bundleIdentifier
        }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: currentApplication.map { [$0] } ?? [],
            exceptingWindows: []
        )

        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        let input = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000
            ]
        )
        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(input) else {
            throw PermissionError.screenCaptureUnavailable("Unable to add audio writer input.")
        }

        writer.add(input)
        assetWriter = writer
        writerInput = input
        didStartSession = false

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        self.stream = stream
        try await stream.startCapture()
    }

    func stop() async {
        let currentStream = stream
        stream = nil

        do {
            try await currentStream?.stopCapture()
        } catch {
            NSLog("System audio stop failed: \(error.localizedDescription)")
        }

        await finishWriting()
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .audio, sampleBuffer.isValid else { return }
        guard let assetWriter, let writerInput else { return }

        if assetWriter.status == .unknown {
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            didStartSession = true
        }

        guard assetWriter.status == .writing, writerInput.isReadyForMoreMediaData else { return }
        writerInput.append(sampleBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("System audio stream stopped: \(error.localizedDescription)")
    }

    private func finishWriting() async {
        guard let assetWriter, let writerInput else { return }

        self.assetWriter = nil
        self.writerInput = nil

        if didStartSession {
            writerInput.markAsFinished()
            await withCheckedContinuation { continuation in
                assetWriter.finishWriting {
                    continuation.resume()
                }
            }
        } else {
            assetWriter.cancelWriting()
        }
    }
}
