import Foundation

/// A rehearsal note the user attaches to a contiguous range of measures on one page
/// (e.g. "여기 박자가 자꾸 밀려요" pinned to measures 5-8). Stored as a start/end
/// measure id pair (DetectedMeasure.id, which is page-local) rather than a Swift
/// ClosedRange so it round-trips through JSON with the rest of the exported score.
public struct FeedbackNote: Codable, Identifiable, Equatable {
    public let id: UUID
    public let pageIndex: Int
    public let startMeasureID: Int
    public let endMeasureID: Int
    public var text: String
    public let createdAt: Date

    public init(id: UUID = UUID(), pageIndex: Int, startMeasureID: Int, endMeasureID: Int, text: String, createdAt: Date = Date()) {
        self.id = id
        self.pageIndex = pageIndex
        self.startMeasureID = min(startMeasureID, endMeasureID)
        self.endMeasureID = max(startMeasureID, endMeasureID)
        self.text = text
        self.createdAt = createdAt
    }

    public func coversMeasure(id: Int) -> Bool {
        (startMeasureID...endMeasureID).contains(id)
    }
}
