import Foundation
import CoreGraphics
import PDFKit

/// Renders a PDFPage into both a displayable CGImage and a GrayscaleImage for analysis,
/// using a top-left-origin pixel space (so detection results line up directly with what
/// SwiftUI draws on screen, with no PDF y-axis flipping needed at the call site).
public enum PDFPageRasterizer {

    /// Upper bound on total pixels in the rasterized buffer (width * height), regardless of
    /// how large `scale` or the source page is. A page with an unusually large MediaBox
    /// combined with a high renderScale slider value could otherwise ask for hundreds of MB
    /// of contiguous memory and crash the app; instead we scale the request down to fit,
    /// which costs detail on a pathological input but never crashes.
    private static let maxPixelCount = 40_000_000 // ~40MP, e.g. ~7100x5600

    public static func rasterize(page: PDFPage, scale: CGFloat) -> (image: CGImage, gray: GrayscaleImage)? {
        guard let cgPage = page.pageRef else { return nil }

        let mediaBox = cgPage.getBoxRect(.mediaBox)
        guard mediaBox.width > 0, mediaBox.height > 0 else { return nil }

        // rotationAngle is one of 0/90/180/270 and reflects the page's own /Rotate entry
        // (degrees clockwise to apply when displaying). We handle it with an explicit,
        // hand-verified rotation below rather than CGPDFPage.getDrawingTransform: that API's
        // own internal flip convention turned out to double up with the y-flip we already do
        // to put row 0 at the visual top, which rendered every page (including ordinary,
        // unrotated ones) upside down.
        let rotation = cgPage.rotationAngle
        let isSideways = rotation == 90 || rotation == 270
        let renderWidth = isSideways ? mediaBox.height : mediaBox.width
        let renderHeight = isSideways ? mediaBox.width : mediaBox.height

        var effectiveScale = scale
        let requestedPixels = Double(renderWidth) * Double(renderHeight) * Double(scale) * Double(scale)
        if requestedPixels > Double(maxPixelCount), requestedPixels > 0 {
            let shrink = (Double(maxPixelCount) / requestedPixels).squareRoot()
            effectiveScale = scale * CGFloat(shrink)
        }

        let pixelWidth = max(1, Int((renderWidth * effectiveScale).rounded()))
        let pixelHeight = max(1, Int((renderHeight * effectiveScale).rounded()))

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: pixelWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        // No y-flip here: this is a raw CGBitmapContext (created with data: nil), whose
        // default coordinate system is already y-up with (0,0) at the bottom-left AND whose
        // underlying pixel buffer stores row 0 as the visual top of whatever is drawn at
        // high y. (The translate+scale(-1) "flip" idiom seen in most PDF-thumbnail sample
        // code is for UIGraphicsImageContext, which is pre-flipped to UIKit's y-down
        // convention; applying that same idiom here double-flips and renders every page,
        // including plain unrotated ones, upside down -- which is exactly the bug this
        // replaced.) A plain positive scale is all that's needed to go from points to pixels.
        context.scaleBy(x: effectiveScale, y: effectiveScale)

        // Rotate the content to match /Rotate, by hand: rotate about the origin by the
        // angle that produces a clockwise-by-`rotation`-degrees display, then translate so
        // the result lands back in the positive (0...renderWidth, 0...renderHeight) range.
        // (CGContext.rotate(by:) is counterclockwise-positive, so a clockwise display
        // rotation of 90 degrees is `rotate(by: -.pi / 2)`, and so on.)
        switch rotation {
        case 90:
            context.translateBy(x: 0, y: mediaBox.width)
            context.rotate(by: -.pi / 2)
        case 180:
            context.translateBy(x: mediaBox.width, y: mediaBox.height)
            context.rotate(by: .pi)
        case 270:
            context.translateBy(x: mediaBox.height, y: 0)
            context.rotate(by: .pi / 2)
        default:
            break
        }

        context.translateBy(x: -mediaBox.minX, y: -mediaBox.minY)
        context.drawPDFPage(cgPage)

        guard let cgImage = context.makeImage(), let data = context.data else { return nil }

        let count = pixelWidth * pixelHeight
        let buffer = data.bindMemory(to: UInt8.self, capacity: count)
        let pixels = [UInt8](UnsafeBufferPointer(start: buffer, count: count))

        let gray = GrayscaleImage(width: pixelWidth, height: pixelHeight, pixels: pixels)
        return (cgImage, gray)
    }
}
