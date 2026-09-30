import XCTest
@testable import ScoreDetectCore

final class OtsuThresholdTests: XCTestCase {

    func testSeparatesTwoClustersCorrectly() {
        // Top half of the image is a "dark ink" cluster (values 10-24), bottom half
        // is a "light background" cluster (values 220-234). Any threshold Otsu picks
        // should classify every pixel from the dark cluster as ink and every pixel
        // from the light cluster as background — that's the property that actually
        // matters for us, regardless of exactly where in the gap it lands.
        let width = 100
        let height = 100
        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let isDarkHalf = y < height / 2
                let jitter = UInt8((x + y) % 15)
                pixels[y * width + x] = isDarkHalf ? (10 + jitter) : (220 + jitter)
            }
        }
        let image = GrayscaleImage(width: width, height: height, pixels: pixels)
        let threshold = OtsuThreshold.compute(for: image)

        for value in 10...24 {
            XCTAssertLessThan(UInt8(value), threshold, "dark cluster pixel \(value) should be classified as ink")
        }
        for value in 220...234 {
            XCTAssertGreaterThanOrEqual(UInt8(value), threshold, "light cluster pixel \(value) should be classified as background")
        }
    }

    func testHandlesUniformImageWithoutCrashing() {
        let image = GrayscaleImage(width: 10, height: 10, pixels: [UInt8](repeating: 255, count: 100))
        // A flat image has no real separating threshold; this just checks it doesn't crash.
        _ = OtsuThreshold.compute(for: image)
    }
}
