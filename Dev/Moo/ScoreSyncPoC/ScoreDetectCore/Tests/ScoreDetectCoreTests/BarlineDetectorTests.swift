import XCTest
@testable import ScoreDetectCore

final class BarlineDetectorTests: XCTestCase {

    /// Builds a white image with a 5-line staff and vertical barlines crossing it at the given x positions.
    private func makeStaffImage(
        width: Int,
        height: Int,
        staffTop: Int,
        spacing: Int,
        barlineXPositions: [Int],
        barlineThickness: Int = 2
    ) -> (GrayscaleImage, StaffLineDetector.Staff) {
        var pixels = [UInt8](repeating: 255, count: width * height)
        let lineYs = (0..<5).map { staffTop + $0 * spacing }

        for y0 in lineYs {
            for t in 0..<2 {
                let y = y0 + t
                guard y >= 0, y < height else { continue }
                for x in 0..<width {
                    pixels[y * width + x] = 0
                }
            }
        }

        let staffBottom = (lineYs.last ?? staffTop) + 2
        for x0 in barlineXPositions {
            for t in 0..<barlineThickness {
                let x = x0 + t
                guard x >= 0, x < width else { continue }
                for y in staffTop..<staffBottom {
                    pixels[y * width + x] = 0
                }
            }
        }

        let image = GrayscaleImage(width: width, height: height, pixels: pixels)
        let staff = StaffLineDetector.Staff(lines: lineYs, spacing: Double(spacing))
        return (image, staff)
    }

    func testDetectsBarlinesBetweenStaffLines() {
        let width = 400
        let spacing = 10
        let barlineXPositions = [50, 150, 250, 350]
        let (image, staff) = makeStaffImage(
            width: width,
            height: 200,
            staffTop: 20,
            spacing: spacing,
            barlineXPositions: barlineXPositions
        )

        let detector = BarlineDetector(parameters: .default)
        let barlines = detector.detectBarlines(in: image, staves: [staff], xRange: 0..<width)

        XCTAssertEqual(barlines.count, barlineXPositions.count)
        for (detected, expected) in zip(barlines, barlineXPositions) {
            XCTAssertEqual(Double(detected.xCenter), Double(expected), accuracy: 2.0)
        }
    }

    func testNoBarlinesWhenStaffHasNoVerticalStrokes() {
        let (image, staff) = makeStaffImage(
            width: 300, height: 200, staffTop: 20, spacing: 10, barlineXPositions: []
        )
        let detector = BarlineDetector(parameters: .default)
        let barlines = detector.detectBarlines(in: image, staves: [staff], xRange: 0..<300)
        XCTAssertEqual(barlines.count, 0)
    }

    func testMergesBarlinesThatAreTooCloseTogether() {
        let width = 200
        let spacing = 10
        // 50 and 53 are closer than the default minBarlineSeparationPx (8), so they
        // should collapse into a single detected barline.
        let (image, staff) = makeStaffImage(
            width: width, height: 200, staffTop: 20, spacing: spacing, barlineXPositions: [50, 53, 150]
        )
        let detector = BarlineDetector(parameters: .default)
        let barlines = detector.detectBarlines(in: image, staves: [staff], xRange: 0..<width)
        XCTAssertEqual(barlines.count, 2)
    }

    func testRejectsWideBlobButKeepsThinBarlineWhenLineThicknessIsKnown() {
        // Simulates the most common real-world false positive: a beam, stacked chord,
        // or dynamics marking that happens to be dark across the same gap rows a
        // barline would be, but is much wider than an actual barline stroke.
        let width = 400
        let spacing = 10
        let staffTop = 20
        var pixels = [UInt8](repeating: 255, count: width * 200)
        let lineYs = (0..<5).map { staffTop + $0 * spacing }
        for y0 in lineYs {
            for t in 0..<2 {
                let y = y0 + t
                for x in 0..<width { pixels[y * width + x] = 0 }
            }
        }
        let staffBottom = (lineYs.last ?? staffTop) + 2

        // A genuine, thin (2px) barline.
        for x in 100..<102 {
            for y in staffTop..<staffBottom { pixels[y * width + x] = 0 }
        }
        // A wide (20px) dark blob — same darkness pattern, but far too wide to be a barline.
        for x in 200..<220 {
            for y in staffTop..<staffBottom { pixels[y * width + x] = 0 }
        }

        let image = GrayscaleImage(width: width, height: 200, pixels: pixels)
        let staff = StaffLineDetector.Staff(lines: lineYs, spacing: Double(spacing))
        let detector = BarlineDetector(parameters: .default)

        let withoutHint = detector.detectBarlines(in: image, staves: [staff], xRange: 0..<width)
        XCTAssertEqual(withoutHint.count, 2, "without a thickness hint, both runs look like valid barlines")

        let withHint = detector.detectBarlines(
            in: image, staves: [staff], xRange: 0..<width, expectedLineThickness: 2.0
        )
        XCTAssertEqual(withHint.count, 1, "the wide blob should be rejected once real barlines are known to be ~2px thick")
        XCTAssertEqual(Double(withHint[0].xCenter), 100, accuracy: 2.0)
    }
}
