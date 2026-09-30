import Foundation
import CoreGraphics

/// A single measure's bounding box, in the rasterized page image's pixel space
/// (origin top-left, x right, y down — same convention as the CGImage/UIImage/NSImage
/// that gets displayed, so overlay drawing needs no coordinate flipping).
public struct DetectedMeasure: Codable, Identifiable, Equatable {
    /// 0-based index across the whole page (System 1 Measure 1, System 1 Measure 2, ..., System 2 Measure 1, ...).
    public let id: Int
    public let systemIndex: Int
    /// 0-based index of this measure within its own System.
    public let indexInSystem: Int
    public let box: CGRect
    /// True if a repeat barline with dots ( |: ) sits at this measure's left edge --
    /// i.e. this is where playback jumps back to when the repeat is taken.
    public let hasRepeatStart: Bool
    /// True if a repeat barline with dots ( :| ) sits at this measure's right edge --
    /// i.e. playback jumps back from here. Volta ("1."/"2.") endings are not detected
    /// (see RepeatBarlineDetector) and don't set this.
    public let hasRepeatEnd: Bool

    public init(
        id: Int,
        systemIndex: Int,
        indexInSystem: Int,
        box: CGRect,
        hasRepeatStart: Bool = false,
        hasRepeatEnd: Bool = false
    ) {
        self.id = id
        self.systemIndex = systemIndex
        self.indexInSystem = indexInSystem
        self.box = box
        self.hasRepeatStart = hasRepeatStart
        self.hasRepeatEnd = hasRepeatEnd
    }
}

/// One System (one line of the score), in the same pixel space as DetectedMeasure.
public struct DetectedSystem: Codable, Identifiable, Equatable {
    /// 0-based index of this System within the page.
    public let id: Int
    public let box: CGRect
    /// Number of staves merged into this System (e.g. 2 for a piano grand staff).
    public let staffCount: Int

    public init(id: Int, box: CGRect, staffCount: Int) {
        self.id = id
        self.box = box
        self.staffCount = staffCount
    }
}

public struct DetectedPage: Codable, Equatable {
    public let pageIndex: Int
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let systems: [DetectedSystem]
    public let measures: [DetectedMeasure]
    /// The ink/background threshold actually used for this page (either the manual
    /// slider value, or an Otsu estimate when auto-calibration is on).
    public let usedDarkThreshold: UInt8
    /// Auto-estimated staff line thickness in pixels, if calibration found one.
    public let estimatedStaffLineThicknessPx: Double?
    /// Auto-estimated staff space (gap between adjacent staff lines) in pixels, if calibration found one.
    public let estimatedStaffSpacePx: Double?
    /// Degrees the page image was rotated by SkewCorrector before detection ran (0 if
    /// correction was disabled, or the page was already judged straight enough).
    /// `nil` only for pages produced before this field existed (kept Optional so old
    /// exported JSON, which never had this key, still decodes instead of failing).
    public let appliedSkewAngleDegrees: Double?

    public init(
        pageIndex: Int,
        pixelWidth: Int,
        pixelHeight: Int,
        systems: [DetectedSystem],
        measures: [DetectedMeasure],
        usedDarkThreshold: UInt8,
        estimatedStaffLineThicknessPx: Double?,
        estimatedStaffSpacePx: Double?,
        appliedSkewAngleDegrees: Double?
    ) {
        self.pageIndex = pageIndex
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.systems = systems
        self.measures = measures
        self.usedDarkThreshold = usedDarkThreshold
        self.estimatedStaffLineThicknessPx = estimatedStaffLineThicknessPx
        self.estimatedStaffSpacePx = estimatedStaffSpacePx
        self.appliedSkewAngleDegrees = appliedSkewAngleDegrees
    }
}

/// Top-level result for a whole PDF, exportable as JSON for inspection outside the app.
public struct DetectedScore: Codable {
    public let sourceFileName: String
    public let parameters: DetectionParameters
    public let pages: [DetectedPage]

    public init(sourceFileName: String, parameters: DetectionParameters, pages: [DetectedPage]) {
        self.sourceFileName = sourceFileName
        self.parameters = parameters
        self.pages = pages
    }
}


/// A (pageIndex, measure) pair placed in whole-piece reading order (page ascending,
/// then system, then position within the system) -- the ordering the audio-sync
/// feature assumes measure playback follows.
public struct OrderedMeasure {
    public let globalIndex: Int
    public let pageIndex: Int
    public let measure: DetectedMeasure
}

public extension DetectedScore {
    /// Every measure across every page, flattened into a single piece-reading-order
    /// list. AudioSyncSettings' global-index math is defined relative to this order.
    var orderedMeasures: [OrderedMeasure] {
        let sortedPages = pages.sorted { $0.pageIndex < $1.pageIndex }
        var result: [OrderedMeasure] = []
        for page in sortedPages {
            let sortedMeasures = page.measures.sorted {
                ($0.systemIndex, $0.indexInSystem) < ($1.systemIndex, $1.indexInSystem)
            }
            for measure in sortedMeasures {
                result.append(OrderedMeasure(globalIndex: result.count, pageIndex: page.pageIndex, measure: measure))
            }
        }
        return result
    }
}
