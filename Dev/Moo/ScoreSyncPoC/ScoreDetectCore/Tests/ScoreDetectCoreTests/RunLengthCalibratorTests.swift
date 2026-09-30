import XCTest
@testable import ScoreDetectCore

final class RunLengthCalibratorTests: XCTestCase {

    /// Builds a page-like image with several repeated 5-line staves at a known line
    /// thickness and staff space, separated by a much larger system gap, so the
    /// paired-run statistics have real repetition to lock onto (similar to a real page).
    private func makeStaffPage(
        width: Int,
        height: Int,
        lineThickness: Int,
        staffSpace: Int,
        staffCount: Int,
        systemGap: Int
    ) -> GrayscaleImage {
        var pixels = [UInt8](repeating: 255, count: width * height)
        var y = 20
        for _ in 0..<staffCount {
            for _ in 0..<5 {
                guard y + lineThickness <= height else { break }
                for t in 0..<lineThickness {
                    for x in 0..<width {
                        pixels[(y + t) * width + x] = 0
                    }
                }
                y += lineThickness + staffSpace
            }
            y += systemGap
        }
        return GrayscaleImage(width: width, height: height, pixels: pixels)
    }

    func testRecoversKnownLineThicknessAndSpacing() {
        let image = makeStaffPage(
            width: 200, height: 800, lineThickness: 3, staffSpace: 11, staffCount: 4, systemGap: 40
        )

        let calibration = RunLengthCalibrator.calibrate(image: image, darkPixelThreshold: 128)
        XCTAssertNotNil(calibration)
        XCTAssertEqual(calibration?.staffLineThickness, 3)
        XCTAssertEqual(calibration?.staffSpaceHeight, 11)
    }

    func testRecoversDifferentKnownThicknessAndSpacing() {
        // A different engraving scale should still be recovered correctly — this
        // guards against accidentally hard-coding anything to the first test's numbers.
        let image = makeStaffPage(
            width: 300, height: 1000, lineThickness: 2, staffSpace: 16, staffCount: 3, systemGap: 60
        )

        let calibration = RunLengthCalibrator.calibrate(image: image, darkPixelThreshold: 128)
        XCTAssertNotNil(calibration)
        XCTAssertEqual(calibration?.staffLineThickness, 2)
        XCTAssertEqual(calibration?.staffSpaceHeight, 16)
    }

    func testReturnsNilForBlankImage() {
        let image = GrayscaleImage(width: 100, height: 100, pixels: [UInt8](repeating: 255, count: 100 * 100))
        XCTAssertNil(RunLengthCalibrator.calibrate(image: image, darkPixelThreshold: 128))
    }
}
