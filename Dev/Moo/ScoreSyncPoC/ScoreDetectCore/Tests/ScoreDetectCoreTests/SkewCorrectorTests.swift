import XCTest
@testable import ScoreDetectCore

final class SkewCorrectorTests: XCTestCase {

    /// Draws 5 "staff lines" as straight horizontal rows, then tilts them by
    /// `angleDegrees` using simple per-column vertical offset (y = base + x*tan(angle)),
    /// independent of SkewCorrector's own rotation implementation, so this is a real
    /// check of its effect rather than a tautology against its own code.
    private func makeTiltedStaffImage(width: Int, height: Int, angleDegrees: Double, lineThickness: Int = 2) -> GrayscaleImage {
        var pixels = [UInt8](repeating: 255, count: width * height)
        let spacing = 12
        let baseYs = (0..<5).map { 60 + $0 * spacing }
        let slope = tan(angleDegrees * .pi / 180)
        for x in 0..<width {
            let dy = Int((Double(x - width / 2) * slope).rounded())
            for base in baseYs {
                for t in 0..<lineThickness {
                    let y = base + dy + t
                    guard y >= 0, y < height else { continue }
                    pixels[y * width + x] = 0
                }
            }
        }
        return GrayscaleImage(width: width, height: height, pixels: pixels)
    }

    /// Same "how peaky is the row-darkness profile" statistic SkewCorrector itself
    /// uses internally, reimplemented here so the test doesn't depend on any private API.
    private func peakinessScore(_ image: GrayscaleImage, darkPixelThreshold: UInt8) -> Double {
        var darkRatios = [Double](repeating: 0, count: image.height)
        for y in 0..<image.height {
            var darkCount = 0
            for x in 0..<image.width where image.value(x: x, y: y) < darkPixelThreshold {
                darkCount += 1
            }
            darkRatios[y] = Double(darkCount) / Double(image.width)
        }
        var score = 0.0
        for y in 1..<darkRatios.count {
            let diff = darkRatios[y] - darkRatios[y - 1]
            score += diff * diff
        }
        return score
    }

    func testCorrectsTiltedStaffLines() {
        let tilted = makeTiltedStaffImage(width: 400, height: 300, angleDegrees: 3.0)
        let uncorrectedScore = peakinessScore(tilted, darkPixelThreshold: 128)

        let result = SkewCorrector.correct(
            tilted,
            darkPixelThreshold: 128,
            maxAngleDegrees: 6.0,
            angleStepDegrees: 0.5,
            downsampleFactor: 2
        )

        // Some correction should have actually been applied (the image was deliberately
        // tilted well outside noise range).
        XCTAssertGreaterThan(abs(result.appliedAngleDegrees), 0.5)

        // And it should have made the row-darkness profile meaningfully sharper/peakier
        // than the uncorrected tilted image — i.e. staff lines are closer to horizontal
        // after correction, not just rotated by some arbitrary amount.
        let correctedScore = peakinessScore(result.image, darkPixelThreshold: 128)
        XCTAssertGreaterThan(correctedScore, uncorrectedScore)
    }

    func testLeavesAlreadyStraightImageEssentiallyUnchanged() {
        let straight = makeTiltedStaffImage(width: 400, height: 300, angleDegrees: 0.0)

        let result = SkewCorrector.correct(
            straight,
            darkPixelThreshold: 128,
            maxAngleDegrees: 6.0,
            angleStepDegrees: 0.5,
            downsampleFactor: 2
        )

        // Should not "correct" a page that's already straight by some spurious amount.
        XCTAssertLessThan(abs(result.appliedAngleDegrees), 0.5)
    }

    func testDisabledWhenMaxAngleIsZero() {
        let tilted = makeTiltedStaffImage(width: 200, height: 200, angleDegrees: 4.0)
        let result = SkewCorrector.correct(
            tilted,
            darkPixelThreshold: 128,
            maxAngleDegrees: 0.0
        )
        XCTAssertEqual(result.appliedAngleDegrees, 0)
        XCTAssertEqual(result.image.pixels, tilted.pixels)
    }
}
