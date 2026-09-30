import XCTest
@testable import ScoreDetectCore

final class StaffLineDetectorTests: XCTestCase {

    /// Builds a white image with black horizontal lines drawn at the given y positions.
    private func makeImage(width: Int, height: Int, lineYPositions: [Int], lineThickness: Int = 2) -> GrayscaleImage {
        var pixels = [UInt8](repeating: 255, count: width * height)
        for y0 in lineYPositions {
            for t in 0..<lineThickness {
                let y = y0 + t
                guard y >= 0, y < height else { continue }
                for x in 0..<width {
                    pixels[y * width + x] = 0
                }
            }
        }
        return GrayscaleImage(width: width, height: height, pixels: pixels)
    }

    func testDetectsFiveEvenlySpacedLinesAsOneStaff() {
        let spacing = 10
        let lineYPositions = (0..<5).map { 20 + $0 * spacing }
        let image = makeImage(width: 300, height: 200, lineYPositions: lineYPositions)

        let detector = StaffLineDetector(parameters: .default)
        let lines = detector.detectLineRows(in: image)
        XCTAssertEqual(lines.count, 5)

        let staves = detector.groupIntoStaves(lines)
        XCTAssertEqual(staves.count, 1)
        XCTAssertEqual(staves[0].lines.count, 5)
    }

    func testGroupsTwoStavesIntoOneSystemWhenClose() {
        let spacing = 10
        let staff1 = (0..<5).map { 20 + $0 * spacing }
        let staff2Start = (staff1.last ?? 0) + spacing * 4 // gap smaller than the default max
        let staff2 = (0..<5).map { staff2Start + $0 * spacing }
        let image = makeImage(width: 300, height: 400, lineYPositions: staff1 + staff2)

        let detector = StaffLineDetector(parameters: .default)
        let lines = detector.detectLineRows(in: image)
        let staves = detector.groupIntoStaves(lines)
        XCTAssertEqual(staves.count, 2)

        let systems = detector.groupIntoSystems(staves)
        XCTAssertEqual(systems.count, 1)
        XCTAssertEqual(systems[0].count, 2)
    }

    func testSplitsIntoSeparateSystemsWhenFarApart() {
        let spacing = 10
        let staff1 = (0..<5).map { 20 + $0 * spacing }
        let staff2Start = (staff1.last ?? 0) + spacing * 20 // gap larger than the default max
        let staff2 = (0..<5).map { staff2Start + $0 * spacing }
        let image = makeImage(width: 300, height: 600, lineYPositions: staff1 + staff2)

        let detector = StaffLineDetector(parameters: .default)
        let lines = detector.detectLineRows(in: image)
        let staves = detector.groupIntoStaves(lines)
        let systems = detector.groupIntoSystems(staves)
        XCTAssertEqual(systems.count, 2)
    }

    func testNoLinesWhenImageIsBlank() {
        let image = GrayscaleImage(width: 100, height: 100, pixels: [UInt8](repeating: 255, count: 100 * 100))
        let detector = StaffLineDetector(parameters: .default)
        XCTAssertEqual(detector.detectLineRows(in: image).count, 0)
    }
}
