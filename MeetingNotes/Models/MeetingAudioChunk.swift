import Foundation

struct MeetingAudioChunk: Codable, Equatable, Identifiable, Sendable {
    enum Source: String, Codable, CaseIterable, Sendable {
        case microphone
        case system
    }

    enum UploadStatus: String, Codable, Sendable {
        case pending
        case compressing
        case compressed
        case uploaded
        case failed
    }

    enum TranscriptionStatus: String, Codable, Sendable {
        case pending
        case completed
        case empty
        case failed
    }

    var id: UUID
    var meetingID: UUID
    var source: Source
    var localFileURL: String?
    var compressedFileURL: String?
    var localFileName: String
    var sequenceIndex: Int
    var durationSeconds: TimeInterval?
    var fileSizeBytes: Int64
    var uploadStatus: UploadStatus
    var transcriptionStatus: TranscriptionStatus
    var storagePath: String?
    var transcriptText: String
    var processingError: String?

    enum CodingKeys: String, CodingKey {
        case id
        case meetingID = "meetingId"
        case source
        case localFileURL
        case compressedFileURL
        case localFileName
        case sequenceIndex
        case durationSeconds
        case fileSizeBytes
        case sizeBytes
        case uploadStatus
        case transcriptionStatus
        case storagePath
        case transcriptText
        case processingError
    }

    init(
        id: UUID = UUID(),
        meetingID: UUID,
        source: Source,
        localFileURL: String?,
        compressedFileURL: String? = nil,
        localFileName: String,
        sequenceIndex: Int,
        durationSeconds: TimeInterval? = nil,
        fileSizeBytes: Int64 = 0,
        uploadStatus: UploadStatus = .pending,
        transcriptionStatus: TranscriptionStatus = .pending,
        storagePath: String? = nil,
        transcriptText: String = "",
        processingError: String? = nil
    ) {
        self.id = id
        self.meetingID = meetingID
        self.source = source
        self.localFileURL = localFileURL
        self.compressedFileURL = compressedFileURL
        self.localFileName = localFileName
        self.sequenceIndex = sequenceIndex
        self.durationSeconds = durationSeconds
        self.fileSizeBytes = fileSizeBytes
        self.uploadStatus = uploadStatus
        self.transcriptionStatus = transcriptionStatus
        self.storagePath = storagePath
        self.transcriptText = transcriptText
        self.processingError = processingError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        meetingID = try container.decode(UUID.self, forKey: .meetingID)
        source = try container.decode(Source.self, forKey: .source)
        localFileURL = try container.decodeIfPresent(String.self, forKey: .localFileURL)
        compressedFileURL = try container.decodeIfPresent(String.self, forKey: .compressedFileURL)
        localFileName = try container.decode(String.self, forKey: .localFileName)
        sequenceIndex = try container.decode(Int.self, forKey: .sequenceIndex)
        durationSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .durationSeconds)
        let decodedFileSizeBytes = try container.decodeIfPresent(Int64.self, forKey: .fileSizeBytes)
        let decodedLegacySizeBytes = try container.decodeIfPresent(Int64.self, forKey: .sizeBytes)
        fileSizeBytes = decodedFileSizeBytes ?? decodedLegacySizeBytes ?? 0
        uploadStatus = try container.decode(UploadStatus.self, forKey: .uploadStatus)
        transcriptionStatus = try container.decode(TranscriptionStatus.self, forKey: .transcriptionStatus)
        storagePath = try container.decodeIfPresent(String.self, forKey: .storagePath)
        transcriptText = try container.decodeIfPresent(String.self, forKey: .transcriptText) ?? ""
        processingError = try container.decodeIfPresent(String.self, forKey: .processingError)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(meetingID, forKey: .meetingID)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(localFileURL, forKey: .localFileURL)
        try container.encodeIfPresent(compressedFileURL, forKey: .compressedFileURL)
        try container.encode(localFileName, forKey: .localFileName)
        try container.encode(sequenceIndex, forKey: .sequenceIndex)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encode(fileSizeBytes, forKey: .fileSizeBytes)
        try container.encode(uploadStatus, forKey: .uploadStatus)
        try container.encode(transcriptionStatus, forKey: .transcriptionStatus)
        try container.encodeIfPresent(storagePath, forKey: .storagePath)
        try container.encode(transcriptText, forKey: .transcriptText)
        try container.encodeIfPresent(processingError, forKey: .processingError)
    }
}
