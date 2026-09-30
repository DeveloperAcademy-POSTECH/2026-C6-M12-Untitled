import Foundation

/// Computes a global binarization threshold via Otsu's method: the threshold that
/// maximizes the between-class variance of pixel intensities, splitting the image
/// into two classes (ink vs. background) without a hand-picked constant. Used so
/// `darkPixelThreshold` can auto-adapt to how a given PDF was rendered (rasterization
/// contrast, anti-aliasing, scan quality all vary) instead of relying only on one
/// fixed slider value for every page.
public enum OtsuThreshold {
    /// Returns the Otsu threshold in 0...255. Pixels with value < threshold are "ink",
    /// matching the convention already used by GrayscaleImage/StaffLineDetector/BarlineDetector.
    public static func compute(for image: GrayscaleImage) -> UInt8 {
        var histogram = [Int](repeating: 0, count: 256)
        for pixel in image.pixels {
            histogram[Int(pixel)] += 1
        }

        let total = image.pixels.count
        guard total > 0 else { return 128 }

        var sumAll = 0.0
        for level in 0..<256 {
            sumAll += Double(level) * Double(histogram[level])
        }

        var sumBackground = 0.0
        var weightBackground = 0
        var maxVariance = -1.0
        var bestThreshold = 128

        for level in 0..<256 {
            weightBackground += histogram[level]
            if weightBackground == 0 { continue }

            let weightForeground = total - weightBackground
            if weightForeground == 0 { break }

            sumBackground += Double(level) * Double(histogram[level])

            let meanBackground = sumBackground / Double(weightBackground)
            let meanForeground = (sumAll - sumBackground) / Double(weightForeground)
            let meanDifference = meanBackground - meanForeground

            let betweenVariance = Double(weightBackground) * Double(weightForeground) * meanDifference * meanDifference

            if betweenVariance > maxVariance {
                maxVariance = betweenVariance
                bestThreshold = level
            }
        }

        return UInt8(bestThreshold)
    }
}
