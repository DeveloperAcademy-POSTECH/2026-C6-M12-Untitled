import Foundation

/// Finds staff lines (5-line groups) and groups them into Systems, purely from
/// row-darkness statistics. No music-symbol understanding — just "is this row
/// mostly ink, and are 5 of them evenly spaced".
public struct StaffLineDetector {
    public struct DetectedLine {
        public let yCenter: Int
        public let thickness: Int
    }

    public struct Staff {
        /// 5 y-centers, top to bottom.
        public let lines: [Int]
        /// Average gap between adjacent lines.
        public let spacing: Double

        public var top: Int { lines.first ?? 0 }
        public var bottom: Int { lines.last ?? 0 }
    }

    let parameters: DetectionParameters

    public init(parameters: DetectionParameters) {
        self.parameters = parameters
    }

    /// Rows whose dark-pixel ratio across the full width clears the threshold are staff-line
    /// candidates. Consecutive candidate rows (a line is usually 2-4px thick at typical render
    /// scales) are merged into one DetectedLine at their vertical center.
    public func detectLineRows(in image: GrayscaleImage) -> [DetectedLine] {
        guard image.width > 0, image.height > 0 else { return [] }

        var darkRatios = [Double](repeating: 0, count: image.height)
        for y in 0..<image.height {
            var darkCount = 0
            let rowStart = y * image.width
            for x in 0..<image.width {
                if image.pixels[rowStart + x] < parameters.darkPixelThreshold {
                    darkCount += 1
                }
            }
            darkRatios[y] = Double(darkCount) / Double(image.width)
        }

        var lines: [DetectedLine] = []
        var runStart: Int?
        for y in 0..<image.height {
            let isLineRow = darkRatios[y] >= parameters.minStaffLineDarkRatio
            if isLineRow {
                if runStart == nil { runStart = y }
            } else if let start = runStart {
                let end = y - 1
                lines.append(DetectedLine(yCenter: (start + end) / 2, thickness: end - start + 1))
                runStart = nil
            }
        }
        if let start = runStart {
            let end = image.height - 1
            lines.append(DetectedLine(yCenter: (start + end) / 2, thickness: end - start + 1))
        }
        return lines
    }

    /// Slides a 5-line window over the detected lines and accepts windows whose 4 internal
    /// gaps are close to equal (within staffSpacingTolerance) as one Staff.
    ///
    /// When `expectedSpacing` is provided (from RunLengthCalibrator, run once per page),
    /// a window also has to match that page-wide spacing estimate, not just be internally
    /// consistent with itself. This rejects coincidental evenly-spaced dark rows that
    /// aren't actually a staff (e.g. a regularly ruled table, or ledger-line clusters)
    /// without changing behavior at all when no estimate is available.
    public func groupIntoStaves(_ lines: [DetectedLine], expectedSpacing: Double? = nil) -> [Staff] {
        guard lines.count >= 5 else { return [] }

        var staves: [Staff] = []
        var i = 0
        while i <= lines.count - 5 {
            let window = Array(lines[i..<(i + 5)])
            let centers = window.map { Double($0.yCenter) }
            let gaps = zip(centers, centers.dropFirst()).map { $1 - $0 }
            let avgGap = gaps.reduce(0, +) / Double(gaps.count)
            let maxDeviation = gaps.map { abs($0 - avgGap) }.max() ?? 0
            let isInternallyEven = avgGap > 0 && (maxDeviation / avgGap) <= parameters.staffSpacingTolerance

            var matchesPageSpacing = true
            if let expectedSpacing, expectedSpacing > 0 {
                matchesPageSpacing = abs(avgGap - expectedSpacing) / expectedSpacing <= parameters.staffSpacingTolerance
            }

            if isInternallyEven && matchesPageSpacing {
                staves.append(Staff(lines: window.map { $0.yCenter }, spacing: avgGap))
                i += 5
            } else {
                i += 1
            }
        }
        return staves
    }

    /// Merges staves that are vertically close (relative to their own line spacing) into one
    /// System, e.g. the two staves of a piano grand staff, or the several staves of a band
    /// part score that are printed as one braced/bracketed system.
    public func groupIntoSystems(_ staves: [Staff]) -> [[Staff]] {
        guard let first = staves.first else { return [] }

        var systems: [[Staff]] = []
        var current: [Staff] = [first]

        for staff in staves.dropFirst() {
            guard let last = current.last else {
                current = [staff]
                continue
            }
            let gap = Double(staff.top - last.bottom)
            let maxGap = last.spacing * parameters.systemGroupingMaxGapInStaffSpaces
            if gap <= maxGap {
                current.append(staff)
            } else {
                systems.append(current)
                current = [staff]
            }
        }
        systems.append(current)
        return systems
    }
}
