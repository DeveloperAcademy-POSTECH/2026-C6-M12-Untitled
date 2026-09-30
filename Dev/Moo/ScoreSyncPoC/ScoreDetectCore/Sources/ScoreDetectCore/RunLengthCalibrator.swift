import Foundation

/// Auto-estimates staff line thickness and staff-space height directly from the image,
/// using the "sum of paired runs" method from Cardoso & Rebelo, "Robust Staffline
/// Thickness and Distance Estimation in Binary and Gray-Level Music Scores" (ICPR 2010).
///
/// The naive approach — take the single most common black-run length as the line
/// thickness, and the single most common white-run length as the staff space,
/// independently — is fragile: a thick stem or a wide margin can each dominate their
/// own histogram on their own. Cardoso & Rebelo's fix is to first histogram the *sum*
/// of one black run immediately followed by one white run. A staff line directly
/// followed by the gap below it is by far the most repeated such pair on any page that
/// has staff lines, so its sum wins even when individual thickness/spacing histograms
/// would be ambiguous. Once the winning sum is known, the most common individual
/// (black, white) pair that adds up to it gives the actual thickness/spacing estimate.
public enum RunLengthCalibrator {
    public struct Calibration {
        public let staffLineThickness: Int
        public let staffSpaceHeight: Int
        /// How many (blackRun, whiteRun) pairs contributed to the winning sum bin.
        /// A very low count (relative to image width) usually means the page doesn't
        /// actually have repeating staff lines at all (e.g. a blank or text-only page).
        public let supportingPairCount: Int
    }

    /// Caps how large a paired run-sum is counted, in pixels. Staff line thickness and
    /// staff space are both small at any sane render scale, so this bounds the histogram
    /// size and skips large gaps (margins, space between systems) that would never win anyway.
    private static let maxPairSum = 160

    public static func calibrate(image: GrayscaleImage, darkPixelThreshold: UInt8) -> Calibration? {
        guard image.width > 0, image.height > 1 else { return nil }

        var sumHistogram = [Int](repeating: 0, count: maxPairSum + 1)
        var pairCounts: [Int: Int] = [:] // key = blackLen * 4096 + whiteLen

        for x in 0..<image.width {
            var y = 0
            var previousBlackLength: Int?

            while y < image.height {
                let runIsInk = image.value(x: x, y: y) < darkPixelThreshold
                var runLength = 0
                while y < image.height, (image.value(x: x, y: y) < darkPixelThreshold) == runIsInk {
                    runLength += 1
                    y += 1
                }

                if runIsInk {
                    previousBlackLength = runLength
                } else if let blackLength = previousBlackLength {
                    let sum = blackLength + runLength
                    if sum <= maxPairSum {
                        sumHistogram[sum] += 1
                        let key = blackLength * 4096 + runLength
                        pairCounts[key, default: 0] += 1
                    }
                    previousBlackLength = nil
                }
            }
        }

        guard let peakSum = sumHistogram.indices.max(by: { sumHistogram[$0] < sumHistogram[$1] }),
              sumHistogram[peakSum] > 0 else {
            return nil
        }

        var bestPair: (black: Int, white: Int, count: Int)?
        for white in 1..<peakSum {
            let black = peakSum - white
            guard black > 0 else { continue }
            let key = black * 4096 + white
            guard let count = pairCounts[key] else { continue }
            if bestPair == nil || count > bestPair!.count {
                bestPair = (black, white, count)
            }
        }

        guard let pair = bestPair else { return nil }
        return Calibration(
            staffLineThickness: pair.black,
            staffSpaceHeight: pair.white,
            supportingPairCount: pair.count
        )
    }
}
