import Foundation

/// Estimates and corrects small rotational skew (a few degrees) before staff-line
/// detection runs. `StaffLineDetector` finds staff lines by looking for rows that are
/// dark all the way across, which only works when the staff lines are actually
/// horizontal in the raster — a photographed or scanned page held even a couple of
/// degrees off-level will smear every staff line across several rows and quietly wreck
/// both the line detector and the run-length calibrator that feeds it. This addresses
/// that directly rather than just noting it as a known limitation.
///
/// Method: classic projection-profile deskew. For a range of candidate angles, rotate a
/// downsampled copy of the page, compute the row-darkness profile (same statistic
/// `StaffLineDetector.detectLineRows` uses), and score how "peaky" that profile is
/// (sum of squared differences between consecutive rows). Real horizontal staff lines
/// produce a profile that alternates sharply between "mostly ink" and "mostly
/// background" rows; the angle that maximizes that sharpness is the correction to
/// apply. This is a standard, well-understood technique — the specific implementation
/// here (downsample for the search, single full-resolution rotation for the result) is
/// just a way to keep it fast enough to run on every page.
public enum SkewCorrector {

    public struct Result {
        public let image: GrayscaleImage
        /// Degrees the image was rotated by (positive = counterclockwise). 0 if no
        /// correction was applied (already straight, or correction disabled/out of range).
        public let appliedAngleDegrees: Double
    }

    /// `maxAngleDegrees <= 0` disables correction entirely (returns the input unchanged).
    public static func correct(
        _ image: GrayscaleImage,
        darkPixelThreshold: UInt8,
        maxAngleDegrees: Double,
        angleStepDegrees: Double = 0.5,
        downsampleFactor: Int = 4
    ) -> Result {
        guard maxAngleDegrees > 0, image.width > 4, image.height > 4 else {
            return Result(image: image, appliedAngleDegrees: 0)
        }

        let small = downsample(image, factor: max(1, downsampleFactor))
        guard small.width > 4, small.height > 4 else {
            return Result(image: image, appliedAngleDegrees: 0)
        }

        var bestAngle = 0.0
        var bestScore = projectionScore(small, angleDegrees: 0, darkPixelThreshold: darkPixelThreshold)

        var angle = -maxAngleDegrees
        while angle <= maxAngleDegrees {
            if abs(angle) > 0.001 {
                let score = projectionScore(small, angleDegrees: angle, darkPixelThreshold: darkPixelThreshold)
                if score > bestScore {
                    bestScore = score
                    bestAngle = angle
                }
            }
            angle += angleStepDegrees
        }

        guard abs(bestAngle) > 0.01 else {
            return Result(image: image, appliedAngleDegrees: 0)
        }

        let rotated = rotate(image, angleDegrees: bestAngle, fillValue: 255)
        return Result(image: rotated, appliedAngleDegrees: bestAngle)
    }

    /// Nearest-neighbor box downsample, used only to make the angle *search* cheap;
    /// the winning angle is re-applied to the full-resolution image separately.
    private static func downsample(_ image: GrayscaleImage, factor: Int) -> GrayscaleImage {
        guard factor > 1 else { return image }
        let newWidth = max(1, image.width / factor)
        let newHeight = max(1, image.height / factor)
        var pixels = [UInt8](repeating: 255, count: newWidth * newHeight)
        for y in 0..<newHeight {
            let sy = min(image.height - 1, y * factor)
            for x in 0..<newWidth {
                let sx = min(image.width - 1, x * factor)
                pixels[y * newWidth + x] = image.value(x: sx, y: sy)
            }
        }
        return GrayscaleImage(width: newWidth, height: newHeight, pixels: pixels)
    }

    /// Rotates the image about its own center by `angleDegrees` (nearest-neighbor,
    /// out-of-bounds source pixels filled with `fillValue`). Safe for the small angles
    /// this is used for (a few degrees) — no attempt is made to be a general-purpose
    /// rotation utility (e.g. no canvas resizing to fit corners).
    private static func rotate(_ image: GrayscaleImage, angleDegrees: Double, fillValue: UInt8) -> GrayscaleImage {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return image }

        let cx = Double(width) / 2.0
        let cy = Double(height) / 2.0
        // Inverse rotation: for each destination pixel, find the source pixel that maps
        // to it, so every destination pixel gets filled (no holes).
        let theta = -angleDegrees * Double.pi / 180.0
        let cosT = cos(theta)
        let sinT = sin(theta)

        var pixels = [UInt8](repeating: fillValue, count: width * height)
        for oy in 0..<height {
            let dy = Double(oy) - cy
            for ox in 0..<width {
                let dx = Double(ox) - cx
                let sx = cx + dx * cosT - dy * sinT
                let sy = cy + dx * sinT + dy * cosT
                let ix = Int(sx.rounded())
                let iy = Int(sy.rounded())
                if ix >= 0, ix < width, iy >= 0, iy < height {
                    pixels[oy * width + ox] = image.value(x: ix, y: iy)
                }
            }
        }
        return GrayscaleImage(width: width, height: height, pixels: pixels)
    }

    /// Higher score = the row-darkness profile at this angle alternates more sharply
    /// between line rows and gap rows, i.e. staff lines are closer to perfectly horizontal.
    private static func projectionScore(_ image: GrayscaleImage, angleDegrees: Double, darkPixelThreshold: UInt8) -> Double {
        let candidate = abs(angleDegrees) < 0.001 ? image : rotate(image, angleDegrees: angleDegrees, fillValue: 255)

        var darkRatios = [Double](repeating: 0, count: candidate.height)
        for y in 0..<candidate.height {
            var darkCount = 0
            let rowStart = y * candidate.width
            for x in 0..<candidate.width {
                if candidate.pixels[rowStart + x] < darkPixelThreshold {
                    darkCount += 1
                }
            }
            darkRatios[y] = Double(darkCount) / Double(candidate.width)
        }

        guard darkRatios.count > 1 else { return 0 }
        var score = 0.0
        for y in 1..<darkRatios.count {
            let diff = darkRatios[y] - darkRatios[y - 1]
            score += diff * diff
        }
        return score
    }
}
