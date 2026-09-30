import Foundation

/// Finds barlines within one System's staves. A real barline is a vertical stroke that
/// crosses every staff line AND the gaps between them; the staff lines themselves are
/// dark in almost every column regardless of barlines, so this only measures darkness in
/// the "gap rows" between adjacent staff lines, which are normally blank/white unless a
/// barline (or a stem/beam/chord, which is a known source of false positives) is there.
public struct BarlineDetector {
    public struct DetectedBarline {
        public let xCenter: Int
    }

    let parameters: DetectionParameters

    public init(parameters: DetectionParameters) {
        self.parameters = parameters
    }

    /// - Parameter expectedLineThickness: when provided (from RunLengthCalibrator), any
    ///   candidate barline wider than `expectedLineThickness * parameters.barlineMaxThicknessMultiplier`
    ///   is rejected. Real barlines are roughly as thick as a staff line; a much wider dark
    ///   run in the gap rows is more likely a beam, a stacked chord, or another symbol that
    ///   happens to cross them. Omit this to keep the old, width-unaware behavior.
    public func detectBarlines(
        in image: GrayscaleImage,
        staves: [StaffLineDetector.Staff],
        xRange: Range<Int>,
        expectedLineThickness: Double? = nil
    ) -> [DetectedBarline] {
        guard !staves.isEmpty else { return [] }

        var gapRows: [Int] = []
        for staff in staves {
            for pairIndex in 0..<(staff.lines.count - 1) {
                let a = staff.lines[pairIndex]
                let b = staff.lines[pairIndex + 1]
                if b - a >= 2 {
                    gapRows.append((a + b) / 2)
                }
            }
        }
        guard !gapRows.isEmpty else { return [] }

        var darkRatios = [Double](repeating: 0, count: image.width)
        for x in xRange {
            var darkCount = 0
            for y in gapRows where image.value(x: x, y: y) < parameters.darkPixelThreshold {
                darkCount += 1
            }
            darkRatios[x] = Double(darkCount) / Double(gapRows.count)
        }

        let maxAllowedWidth: Int? = expectedLineThickness.map { thickness in
            max(1, Int((thickness * parameters.barlineMaxThicknessMultiplier).rounded()))
        }

        var barlines: [DetectedBarline] = []
        func closeRun(start: Int, end: Int) {
            let width = end - start + 1
            if let maxAllowedWidth, width > maxAllowedWidth {
                return // too wide to be a single barline stroke — likely a beam/chord/other symbol
            }
            barlines.append(DetectedBarline(xCenter: (start + end) / 2))
        }

        var runStart: Int?
        for x in xRange {
            let isBarlineColumn = darkRatios[x] >= parameters.minBarlineDarkRatio
            if isBarlineColumn {
                if runStart == nil { runStart = x }
            } else if let start = runStart {
                closeRun(start: start, end: x - 1)
                runStart = nil
            }
        }
        if let start = runStart {
            closeRun(start: start, end: xRange.upperBound - 1)
        }

        var merged: [DetectedBarline] = []
        for bar in barlines {
            if let lastBar = merged.last, bar.xCenter - lastBar.xCenter < parameters.minBarlineSeparationPx {
                continue
            }
            merged.append(bar)
        }
        return merged
    }
}
