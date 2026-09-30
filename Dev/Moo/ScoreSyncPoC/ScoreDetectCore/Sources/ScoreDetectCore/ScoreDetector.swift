import Foundation
import CoreGraphics
import PDFKit

/// Top-level entry point: rasterizes a PDF page/document and runs the staff-line +
/// barline detectors to produce System and Measure boxes in the rasterized image's
/// pixel space (see GrayscaleImage / DetectedMeasure for the coordinate convention).
///
/// Pipeline, in order:
/// 1. Rasterize the PDF page (accounting for the page's own /Rotate attribute, and
///    capping resolution so a pathological renderScale/page-size combination can't
///    exhaust memory — see PDFPageRasterizer).
/// 2. If `useAutoCalibration`, estimate a binarization threshold with Otsu's method.
///    Otherwise use the manually configured `darkPixelThreshold`.
/// 3. If `useSkewCorrection`, estimate and correct a small rotational skew (a few
///    degrees) using that threshold — this has to happen before step 4, since a tilted
///    page corrupts the run-length statistics step 4 depends on.
/// 4. If `useAutoCalibration`, estimate staff-line thickness / staff-space with the
///    run-length method from Cardoso & Rebelo (2010).
/// 5. Detect staff lines, group them into Staves and Systems, detect barlines, and
///    build Measure boxes — using the calibrated threshold/spacing/thickness from
///    steps 2-4 as cross-checks where available.
public enum ScoreDetector {
    public static func detectPage(_ page: PDFPage, pageIndex: Int, parameters: DetectionParameters) -> DetectedPage? {
        guard let rasterized = PDFPageRasterizer.rasterize(page: page, scale: parameters.renderScale) else {
            return nil
        }
        var gray = rasterized.gray

        // A page with no pixels (shouldn't happen given PDFPageRasterizer's guards, but
        // cheap to double-check here since every step below assumes width/height > 0)
        // still returns a well-formed, empty result rather than propagating a crash.
        guard gray.width > 0, gray.height > 0 else {
            return DetectedPage(
                pageIndex: pageIndex,
                pixelWidth: gray.width,
                pixelHeight: gray.height,
                systems: [],
                measures: [],
                usedDarkThreshold: parameters.darkPixelThreshold,
                estimatedStaffLineThicknessPx: nil,
                estimatedStaffSpacePx: nil,
                appliedSkewAngleDegrees: nil
            )
        }

        var effectiveThreshold = parameters.darkPixelThreshold
        if parameters.useAutoCalibration {
            effectiveThreshold = OtsuThreshold.compute(for: gray)
        }

        var appliedSkewAngle = 0.0
        if parameters.useSkewCorrection && parameters.maxSkewCorrectionDegrees > 0 {
            let skewResult = SkewCorrector.correct(
                gray,
                darkPixelThreshold: effectiveThreshold,
                maxAngleDegrees: parameters.maxSkewCorrectionDegrees
            )
            gray = skewResult.image
            appliedSkewAngle = skewResult.appliedAngleDegrees
        }

        var calibration: RunLengthCalibrator.Calibration?
        if parameters.useAutoCalibration {
            calibration = RunLengthCalibrator.calibrate(image: gray, darkPixelThreshold: effectiveThreshold)
        }

        var effectiveParameters = parameters
        effectiveParameters.darkPixelThreshold = effectiveThreshold

        let lineDetector = StaffLineDetector(parameters: effectiveParameters)
        let lines = lineDetector.detectLineRows(in: gray)
        let expectedSpacing = calibration.map { Double($0.staffSpaceHeight) }
        let staves = lineDetector.groupIntoStaves(lines, expectedSpacing: expectedSpacing)
        let systemsOfStaves = lineDetector.groupIntoSystems(staves)

        let barDetector = BarlineDetector(parameters: effectiveParameters)
        let expectedLineThickness = calibration.map { Double($0.staffLineThickness) }

        var detectedSystems: [DetectedSystem] = []
        var detectedMeasures: [DetectedMeasure] = []
        var measureCounter = 0

        for (systemIndex, staffGroup) in systemsOfStaves.enumerated() {
            guard let firstStaff = staffGroup.first, let lastStaff = staffGroup.last else { continue }

            let xRange = 0..<gray.width
            let systemTop = firstStaff.top
            let systemBottom = lastStaff.bottom
            guard systemBottom >= systemTop else { continue }
            let systemBox = CGRect(
                x: 0,
                y: Double(systemTop),
                width: Double(gray.width),
                height: Double(systemBottom - systemTop)
            )

            let barlines = barDetector.detectBarlines(
                in: gray, staves: staffGroup, xRange: xRange, expectedLineThickness: expectedLineThickness
            )
            let xPositions = ([0] + barlines.map { $0.xCenter } + [gray.width]).sorted()

            // Which of the raw candidate x-positions are safe to test for repeat
            // dots at all. Two guards, both aimed at the same failure mode: a clef +
            // key signature is dense enough that a false barline strike can land
            // inside it, carving out a "measure" that's technically wide enough to
            // pass minMeasureWidthPx (so it still gets drawn as a measure box) but
            // is really just leftover header clutter, not a bar of real music -- and
            // an accidental sitting right there reads as a repeat dot.
            //
            // 1. A genuine barline that only produces a sliver too narrow to ever be
            //    drawn never becomes a real edge here, so repeat-dot search never
            //    gets pointed at it either (this alone doesn't catch the case above,
            //    where the sliver is wide enough to pass minMeasureWidthPx -- guard 2
            //    handles that one).
            // 2. A "measure" that passes minMeasureWidthPx but is still far narrower
            //    than a real bar of music has any business being (using the staff's
            //    own spacing as the ruler, not a fixed pixel count, so this scales
            //    with the page's render resolution) is excluded too. Real music needs
            //    room for at least a notehead plus some breathing space; a couple of
            //    staff-spaces is already generous as a floor.
            let repeatEligibleMinWidth: Int = {
                guard let spacing = expectedSpacing else {
                    return effectiveParameters.minMeasureWidthPx
                }
                return max(effectiveParameters.minMeasureWidthPx, Int((spacing * 2.5).rounded()))
            }()
            var confirmedEdgeXs = Set<Int>()
            var repeatEligibleEdgeXs = Set<Int>()
            for i in 0..<max(0, xPositions.count - 1) {
                let left = xPositions[i]
                let right = xPositions[i + 1]
                let width = right - left
                guard width >= effectiveParameters.minMeasureWidthPx else { continue }
                if left != 0 { confirmedEdgeXs.insert(left) }
                if right != gray.width { confirmedEdgeXs.insert(right) }
                guard width >= repeatEligibleMinWidth else { continue }
                if left != 0 { repeatEligibleEdgeXs.insert(left) }
                if right != gray.width { repeatEligibleEdgeXs.insert(right) }
            }
            // A barline only qualifies as a repeat-dot candidate if the measure on
            // BOTH sides of it is a plausible size -- if either neighbor is really
            // just header/footer clutter, the ink sitting there (an accidental, a
            // clef curve, a time-signature digit) can't be trusted not to be mistaken
            // for a dot, regardless of which side the dots would notionally belong to.
            let confirmedBarlineXs = barlines.map { $0.xCenter }.filter { confirmedEdgeXs.contains($0) }
            let repeatCandidateBarlineXs = barlines.map { $0.xCenter }.filter { repeatEligibleEdgeXs.contains($0) }

            // Repeat dots are engraved per-staff; checking every staff in the System (not
            // just the first) means a repeat still gets caught if the engraver only put the
            // dots on one staff of a grand staff, without needing to know which one.
            let repeatDetector = RepeatBarlineDetector(parameters: effectiveParameters)
            var repeatsByX: [Int: RepeatBarlineDetector.RepeatSide] = [:]
            let leadingBarlineX = repeatCandidateBarlineXs.min()
            let allBarlineXsInSystem = barlines.map { $0.xCenter }
            for staff in staffGroup {
                let found = repeatDetector.detectRepeats(
                    in: gray, staff: staff, barlineXPositions: repeatCandidateBarlineXs,
                    allBarlineXPositionsInSystem: allBarlineXsInSystem, skipLeftSearchAt: leadingBarlineX
                )
                for (x, side) in found {
                    if let existing = repeatsByX[x], existing != side {
                        repeatsByX[x] = .both
                    } else {
                        repeatsByX[x] = side
                    }
                }
            }

            var measureIndexInSystem = 0
            for i in 0..<max(0, xPositions.count - 1) {
                let left = xPositions[i]
                let right = xPositions[i + 1]
                let width = right - left
                guard width >= effectiveParameters.minMeasureWidthPx else { continue }

                let box = CGRect(
                    x: Double(left),
                    y: Double(systemTop),
                    width: Double(width),
                    height: Double(systemBottom - systemTop)
                )
                let leftRepeat = repeatsByX[left]
                let rightRepeat = repeatsByX[right]
                let hasRepeatStart = leftRepeat == .start || leftRepeat == .both
                let hasRepeatEnd = rightRepeat == .end || rightRepeat == .both
                detectedMeasures.append(
                    DetectedMeasure(
                        id: measureCounter,
                        systemIndex: systemIndex,
                        indexInSystem: measureIndexInSystem,
                        box: box,
                        hasRepeatStart: hasRepeatStart,
                        hasRepeatEnd: hasRepeatEnd
                    )
                )
                measureCounter += 1
                measureIndexInSystem += 1
            }

            detectedSystems.append(DetectedSystem(id: systemIndex, box: systemBox, staffCount: staffGroup.count))
        }

        return DetectedPage(
            pageIndex: pageIndex,
            pixelWidth: gray.width,
            pixelHeight: gray.height,
            systems: detectedSystems,
            measures: detectedMeasures,
            usedDarkThreshold: effectiveThreshold,
            estimatedStaffLineThicknessPx: expectedLineThickness,
            estimatedStaffSpacePx: expectedSpacing,
            appliedSkewAngleDegrees: appliedSkewAngle
        )
    }

    public static func detectDocument(_ document: PDFDocument, fileName: String, parameters: DetectionParameters) -> DetectedScore {
        var pages: [DetectedPage] = []
        guard !document.isLocked else {
            // Encrypted/password-protected PDFs decode as a valid PDFDocument but every
            // page comes back blank until unlocked — better to say so explicitly (via an
            // empty result the caller can detect) than to silently "detect" nothing and
            // let the user think their score just has no staff lines on it.
            return DetectedScore(sourceFileName: fileName, parameters: parameters, pages: pages)
        }
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            if let detected = detectPage(page, pageIndex: i, parameters: parameters) {
                pages.append(detected)
            }
        }
        return DetectedScore(sourceFileName: fileName, parameters: parameters, pages: pages)
    }
}
