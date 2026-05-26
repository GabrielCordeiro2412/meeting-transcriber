import Foundation

struct MeetingSummaryResult: Codable, Equatable, Sendable {
    var title: String
    var summary: String
    var detailedNotes: [String]
    var topics: [String]
    var keyPoints: [String]
    var decisions: [String]
    var actionItems: [String]
    var openQuestions: [String]
    var risksOrBlockers: [String]
    var followUpItems: [String]

    static let empty = MeetingSummaryResult(
        title: "",
        summary: "",
        detailedNotes: [],
        topics: [],
        keyPoints: [],
        decisions: [],
        actionItems: [],
        openQuestions: [],
        risksOrBlockers: [],
        followUpItems: []
    )
}
