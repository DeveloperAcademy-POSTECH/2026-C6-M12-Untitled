import Foundation
import CoreGraphics

/// Tunable thresholds for the CV-based System/Barline detector.
/// Everything here is intentionally simple (row/column darkness ratios, plus a few
/// auto-calibration/correction steps) so the whole pipeline stays inspectable and fast
/// on-device; no ML model involved.
public struct DetectionParameters: Codable, Equatable {
    /// How many pixels per PDF point to render at. Higher = more accurate but slower.
    /// The actual render resolution is silently capped for very large pages (see
    /// PDFPageRasterizer.maxPixelCount) so an aggressive value here can't exhaust memory.
    public var renderScale: CGFloat

    /// Grayscale value (0-255) below which a pixel is considered "ink". Only used
    /// as-is when `useAutoCalibration` is false — otherwise it's overridden per
    /// page by an Otsu threshold computed from that page's own pixel histogram.
    public var darkPixelThreshold: UInt8

    /// If true (default), the detector estimates its own binarization threshold
    /// (Otsu's method) and its own staff-line-thickness / staff-space estimate
    /// (Cardoso & Rebelo's paired run-length method) directly from the page,
    /// instead of relying only on the manually tuned values below. This is what
    /// makes results hold up across PDFs rendered with different contrast/engraving
    /// sizes without re-tuning every slider by hand. Turn it off to fall back to
    /// the older, fully manual behavior.
    public var useAutoCalibration: Bool

    /// If true (default), a small rotational skew (up to `maxSkewCorrectionDegrees`)
    /// is estimated and corrected before staff-line detection runs. Matters most for
    /// scanned/photographed pages, which are rarely perfectly level. Set to false (or
    /// `maxSkewCorrectionDegrees` to 0) to skip this — it costs extra time per page.
    public var useSkewCorrection: Bool
    /// Largest rotation (in degrees, either direction) the skew corrector is allowed to
    /// search for and apply. Kept small on purpose: this is meant to fix "page wasn't
    /// held quite level", not stand in for manually rotating a badly misaligned scan.
    public var maxSkewCorrectionDegrees: Double

    /// Fraction of a row's width that must be dark for the row to count as part of a staff line.
    public var minStaffLineDarkRatio: Double
    /// Allowed relative deviation between the 5 line gaps within one staff (0.25 = ±25%).
    public var staffSpacingTolerance: Double
    /// Max vertical gap between two staves (in multiples of staff-line spacing) to still
    /// treat them as the same System (e.g. grand staff, multi-instrument system).
    public var systemGroupingMaxGapInStaffSpaces: Double
    /// Fraction of the staff's "gap rows" (rows between staff lines) that must be dark
    /// at a given column for that column to count as a barline.
    public var minBarlineDarkRatio: Double
    /// Minimum pixel distance between two detected barlines; closer ones are merged.
    public var minBarlineSeparationPx: Int
    /// Measures narrower than this (in pixels) are dropped as noise.
    public var minMeasureWidthPx: Int
    /// When auto-calibration found a staff-line thickness, a barline candidate wider
    /// than (estimated thickness × this multiplier) is rejected — real barlines are
    /// roughly as thick as a staff line; a much wider dark run is more likely a beam,
    /// a stacked chord, a dynamics marking, or other symbol. Ignored if calibration
    /// didn't find a usable estimate.
    public var barlineMaxThicknessMultiplier: Double

    public init(
        renderScale: CGFloat = 3.0,
        darkPixelThreshold: UInt8 = 128,
        useAutoCalibration: Bool = true,
        useSkewCorrection: Bool = true,
        maxSkewCorrectionDegrees: Double = 5.0,
        minStaffLineDarkRatio: Double = 0.55,
        staffSpacingTolerance: Double = 0.25,
        systemGroupingMaxGapInStaffSpaces: Double = 6.0,
        minBarlineDarkRatio: Double = 0.6,
        minBarlineSeparationPx: Int = 8,
        minMeasureWidthPx: Int = 20,
        barlineMaxThicknessMultiplier: Double = 4.0
    ) {
        self.renderScale = renderScale
        self.darkPixelThreshold = darkPixelThreshold
        self.useAutoCalibration = useAutoCalibration
        self.useSkewCorrection = useSkewCorrection
        self.maxSkewCorrectionDegrees = maxSkewCorrectionDegrees
        self.minStaffLineDarkRatio = minStaffLineDarkRatio
        self.staffSpacingTolerance = staffSpacingTolerance
        self.systemGroupingMaxGapInStaffSpaces = systemGroupingMaxGapInStaffSpaces
        self.minBarlineDarkRatio = minBarlineDarkRatio
        self.minBarlineSeparationPx = minBarlineSeparationPx
        self.minMeasureWidthPx = minMeasureWidthPx
        self.barlineMaxThicknessMultiplier = barlineMaxThicknessMultiplier
    }

    public static let `default` = DetectionParameters()

    // MARK: - Codable

    // Hand-written instead of relying on the synthesized implementation, so that a
    // JSON file exported by an older version of this app (before `useSkewCorrection` /
    // `maxSkewCorrectionDegrees` existed) still decodes instead of throwing — missing
    // fields fall back to `DetectionParameters.default`'s values rather than failing
    // the whole import.
    private enum CodingKeys: String, CodingKey {
        case renderScale, darkPixelThreshold, useAutoCalibration, useSkewCorrection,
             maxSkewCorrectionDegrees, minStaffLineDarkRatio, staffSpacingTolerance,
             systemGroupingMaxGapInStaffSpaces, minBarlineDarkRatio, minBarlineSeparationPx,
             minMeasureWidthPx, barlineMaxThicknessMultiplier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = DetectionParameters.default
        renderScale = try container.decodeIfPresent(CGFloat.self, forKey: .renderScale) ?? fallback.renderScale
        darkPixelThreshold = try container.decodeIfPresent(UInt8.self, forKey: .darkPixelThreshold) ?? fallback.darkPixelThreshold
        useAutoCalibration = try container.decodeIfPresent(Bool.self, forKey: .useAutoCalibration) ?? fallback.useAutoCalibration
        useSkewCorrection = try container.decodeIfPresent(Bool.self, forKey: .useSkewCorrection) ?? fallback.useSkewCorrection
        maxSkewCorrectionDegrees = try container.decodeIfPresent(Double.self, forKey: .maxSkewCorrectionDegrees) ?? fallback.maxSkewCorrectionDegrees
        minStaffLineDarkRatio = try container.decodeIfPresent(Double.self, forKey: .minStaffLineDarkRatio) ?? fallback.minStaffLineDarkRatio
        staffSpacingTolerance = try container.decodeIfPresent(Double.self, forKey: .staffSpacingTolerance) ?? fallback.staffSpacingTolerance
        systemGroupingMaxGapInStaffSpaces = try container.decodeIfPresent(Double.self, forKey: .systemGroupingMaxGapInStaffSpaces) ?? fallback.systemGroupingMaxGapInStaffSpaces
        minBarlineDarkRatio = try container.decodeIfPresent(Double.self, forKey: .minBarlineDarkRatio) ?? fallback.minBarlineDarkRatio
        minBarlineSeparationPx = try container.decodeIfPresent(Int.self, forKey: .minBarlineSeparationPx) ?? fallback.minBarlineSeparationPx
        minMeasureWidthPx = try container.decodeIfPresent(Int.self, forKey: .minMeasureWidthPx) ?? fallback.minMeasureWidthPx
        barlineMaxThicknessMultiplier = try container.decodeIfPresent(Double.self, forKey: .barlineMaxThicknessMultiplier) ?? fallback.barlineMaxThicknessMultiplier
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(renderScale, forKey: .renderScale)
        try container.encode(darkPixelThreshold, forKey: .darkPixelThreshold)
        try container.encode(useAutoCalibration, forKey: .useAutoCalibration)
        try container.encode(useSkewCorrection, forKey: .useSkewCorrection)
        try container.encode(maxSkewCorrectionDegrees, forKey: .maxSkewCorrectionDegrees)
        try container.encode(minStaffLineDarkRatio, forKey: .minStaffLineDarkRatio)
        try container.encode(staffSpacingTolerance, forKey: .staffSpacingTolerance)
        try container.encode(systemGroupingMaxGapInStaffSpaces, forKey: .systemGroupingMaxGapInStaffSpaces)
        try container.encode(minBarlineDarkRatio, forKey: .minBarlineDarkRatio)
        try container.encode(minBarlineSeparationPx, forKey: .minBarlineSeparationPx)
        try container.encode(minMeasureWidthPx, forKey: .minMeasureWidthPx)
        try container.encode(barlineMaxThicknessMultiplier, forKey: .barlineMaxThicknessMultiplier)
    }
}
