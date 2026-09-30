import Foundation

/// A simple 8-bit grayscale pixel buffer (0 = black, 255 = white), row-major.
/// Kept as a plain struct (no CoreGraphics dependency) so the detection logic
/// in this file and StaffLineDetector/BarlineDetector can be unit-tested with
/// synthetic images that don't require rendering a real PDF.
public struct GrayscaleImage {
    public let width: Int
    public let height: Int
    public var pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height, "pixel buffer size must equal width * height")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    @inline(__always)
    public func value(x: Int, y: Int) -> UInt8 {
        pixels[y * width + x]
    }
}
