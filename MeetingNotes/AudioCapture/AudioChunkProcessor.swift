import Foundation

struct PreparedAudioChunk: Sendable {
    var chunk: MeetingAudioChunk
    var uploadFileURL: URL
}

enum AudioChunkProcessorError: LocalizedError {
    case conversionFailed(String)
    case afconvertUnavailable

    var errorDescription: String? {
        switch self {
        case .conversionFailed(let message):
            return message
        case .afconvertUnavailable:
            return "The system audio conversion tool is unavailable."
        }
    }
}

struct AudioChunkProcessor {
    static let shared = AudioChunkProcessor()

    let maxChunkDuration: TimeInterval = 6 * 60
    let maxUploadBytes: Int64 = 20 * 1024 * 1024

    func prepareChunks(
        meetingID: UUID,
        source: MeetingAudioChunk.Source,
        sourceURLs: [URL]
    ) async throws -> [PreparedAudioChunk] {
        var prepared: [PreparedAudioChunk] = []
        var sequenceIndex = 0

        for sourceURL in sourceURLs {
            let duration = durationSeconds(for: sourceURL) ?? 0
            let sourceSize = fileSize(for: sourceURL)
            let chunkDuration = chunkDuration(forDuration: duration, fileSizeBytes: sourceSize)
            let shouldSplit = source == .microphone && (duration > chunkDuration || sourceSize > maxUploadBytes)

            let splitURLs = shouldSplit
                ? try splitWaveFile(inputURL: sourceURL, chunkDuration: chunkDuration)
                : [sourceURL]

            for splitURL in splitURLs {
                let uploadURL = try await uploadReadyURL(sourceURL: splitURL, source: source)
                let size = fileSize(for: uploadURL)
                let duration = durationSeconds(for: splitURL)
                let chunk = MeetingAudioChunk(
                    meetingID: meetingID,
                    source: source,
                    localFileURL: splitURL.path,
                    compressedFileURL: uploadURL == splitURL ? nil : uploadURL.path,
                    localFileName: uploadURL.lastPathComponent,
                    sequenceIndex: sequenceIndex,
                    durationSeconds: duration,
                    fileSizeBytes: size,
                    uploadStatus: .compressed,
                    transcriptionStatus: .pending
                )
                prepared.append(PreparedAudioChunk(chunk: chunk, uploadFileURL: uploadURL))
                sequenceIndex += 1
            }
        }

        return prepared
    }

    private func uploadReadyURL(sourceURL: URL, source: MeetingAudioChunk.Source) async throws -> URL {
        if source == .system {
            return sourceURL
        }

        if fileSize(for: sourceURL) <= maxUploadBytes {
            return sourceURL
        }

        return try await compress(sourceURL: sourceURL)
    }

    private func compress(sourceURL: URL) async throws -> URL {
        let outputURL = sourceURL.deletingPathExtension().appendingPathExtension("m4a")
        try? FileManager.default.removeItem(at: outputURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            "-f", "m4af",
            "-d", "aac",
            "-b", "64000",
            sourceURL.path,
            outputURL.path,
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw AudioChunkProcessorError.afconvertUnavailable
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = detail.map { " \($0)" } ?? ""
            throw AudioChunkProcessorError.conversionFailed("Audio compression failed for \(sourceURL.lastPathComponent).\(suffix)")
        }
        return outputURL
    }

    private func chunkDuration(forDuration duration: TimeInterval, fileSizeBytes: Int64) -> TimeInterval {
        guard duration > 0, fileSizeBytes > 0 else {
            return maxChunkDuration
        }

        let bytesPerSecond = Double(fileSizeBytes) / duration
        guard bytesPerSecond > 0 else {
            return maxChunkDuration
        }

        let byteLimitedDuration = (Double(maxUploadBytes) * 0.85) / bytesPerSecond
        return max(30, min(maxChunkDuration, byteLimitedDuration))
    }

    private func fileSize(for url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: Set([URLResourceKey.fileSizeKey]))
        return values?.fileSize.map(Int64.init) ?? 0
    }

    private func splitWaveFile(inputURL: URL, chunkDuration: TimeInterval) throws -> [URL] {
        let reader = try WaveReader(url: inputURL)
        let framesPerChunk = Int(Double(reader.sampleRate) * chunkDuration)
        guard framesPerChunk > 0 else { return [inputURL] }

        let totalChunks = Int(ceil(Double(reader.frameCount) / Double(framesPerChunk)))
        guard totalChunks > 1 else { return [inputURL] }

        let directory = inputURL.deletingLastPathComponent()
        var urls: [URL] = []
        for index in 0..<totalChunks {
            let startFrame = index * framesPerChunk
            let frameCount = min(framesPerChunk, reader.frameCount - startFrame)
            guard frameCount > 0 else { continue }

            let outputURL = directory.appending(path: "\(inputURL.deletingPathExtension().lastPathComponent)-part-\(String(index + 1).padLeft(toLength: 2, withPad: "0")).wav")
            try reader.writeChunk(to: outputURL, startFrame: startFrame, frameCount: frameCount)
            urls.append(outputURL)
        }
        return urls
    }

    private func durationSeconds(for url: URL) -> TimeInterval? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afinfo")
        process.arguments = [url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        let prefix = "estimated duration:"
        guard let line = output.components(separatedBy: .newlines).first(where: { $0.contains(prefix) }) else {
            return nil
        }

        let raw = line
            .replacingOccurrences(of: prefix, with: "")
            .replacingOccurrences(of: "sec", with: "")
            .trimmingCharacters(in: .whitespaces)
        return TimeInterval(raw)
    }
}

private struct WaveReader {
    let url: URL
    let data: Data
    let formatTag: Int
    let sampleRate: Int
    let channels: Int
    let bitsPerSample: Int
    let dataOffset: Int
    let dataSize: Int

    var bytesPerFrame: Int {
        channels * bitsPerSample / 8
    }

    var frameCount: Int {
        dataSize / max(bytesPerFrame, 1)
    }

    init(url: URL) throws {
        self.url = url
        self.data = try Data(contentsOf: url)
        let rawData = self.data

        func readUInt16(_ offset: Int) -> UInt16 {
            let range = offset..<(offset + 2)
            return rawData.subdata(in: range).withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
        }

        func readUInt32(_ offset: Int) -> UInt32 {
            let range = offset..<(offset + 4)
            return rawData.subdata(in: range).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
        }

        guard String(data: rawData.prefix(4), encoding: .ascii) == "RIFF" else {
            throw AudioChunkProcessorError.conversionFailed("Unsupported WAV header in \(url.lastPathComponent).")
        }

        var offset = 12
        var formatTag = 1
        var formatChannels = 1
        var formatSampleRate = 16_000
        var formatBits = 16
        var payloadOffset = 44
        var payloadSize = max(rawData.count - 44, 0)

        while offset + 8 <= rawData.count {
            let chunkID = String(data: rawData[offset..<(offset + 4)], encoding: .ascii) ?? ""
            let chunkSize = Int(readUInt32(offset + 4))
            let chunkDataOffset = offset + 8
            if chunkID == "fmt " {
                formatTag = Int(readUInt16(chunkDataOffset))
                formatChannels = Int(readUInt16(chunkDataOffset + 2))
                formatSampleRate = Int(readUInt32(chunkDataOffset + 4))
                formatBits = Int(readUInt16(chunkDataOffset + 14))
            } else if chunkID == "data" {
                payloadOffset = chunkDataOffset
                payloadSize = chunkSize
                break
            }
            offset = chunkDataOffset + chunkSize + (chunkSize % 2)
        }

        self.formatTag = formatTag
        self.channels = formatChannels
        self.sampleRate = formatSampleRate
        self.bitsPerSample = formatBits
        self.dataOffset = payloadOffset
        self.dataSize = payloadSize
    }

    func writeChunk(to outputURL: URL, startFrame: Int, frameCount: Int) throws {
        let chunkByteOffset = dataOffset + (startFrame * bytesPerFrame)
        let chunkByteSize = frameCount * bytesPerFrame
        let payload = data.subdata(in: chunkByteOffset..<(chunkByteOffset + chunkByteSize))

        var header = Data()
        header.append("RIFF".data(using: .ascii)!)
        header.append(UInt32(36 + payload.count).littleEndianData)
        header.append("WAVE".data(using: .ascii)!)
        header.append("fmt ".data(using: .ascii)!)
        header.append(UInt32(16).littleEndianData)
        header.append(UInt16(formatTag).littleEndianData)
        header.append(UInt16(channels).littleEndianData)
        header.append(UInt32(sampleRate).littleEndianData)
        header.append(UInt32(sampleRate * bytesPerFrame).littleEndianData)
        header.append(UInt16(bytesPerFrame).littleEndianData)
        header.append(UInt16(bitsPerSample).littleEndianData)
        header.append("data".data(using: .ascii)!)
        header.append(UInt32(payload.count).littleEndianData)

        var output = Data()
        output.append(header)
        output.append(payload)
        try output.write(to: outputURL, options: .atomic)
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}

private extension String {
    func padLeft(toLength: Int, withPad character: Character) -> String {
        guard count < toLength else { return self }
        return String(repeating: String(character), count: toLength - count) + self
    }
}
