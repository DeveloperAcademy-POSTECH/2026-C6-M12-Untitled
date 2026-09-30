import Foundation

/// Detects repeat-barline dots (도돌이표) next to already-detected barlines.
///
/// A repeat barline is a plain barline paired with two round dots stacked in the
/// staff's two middle spaces (straddling the middle line). This detector doesn't try
/// to tell a "thin" barline from a "thick" one -- the dots alone are the reliable
/// signal, and they're what actually carries the musical meaning:
///   - dots to the RIGHT of a barline  -> repeat starts here ( |: )
///   - dots to the LEFT of a barline   -> repeat ends here   ( :| )
///   - dots on BOTH sides              -> repeat ends and a new one starts here ( :|: )
/// Volta brackets ("1." / "2." endings) are a separate, unrelated symbol (a bracket +
/// text above the staff, not a barline decoration) and are intentionally out of scope
/// here.
public struct RepeatBarlineDetector {
    public enum RepeatSide: Equatable {
        case start
        case end
        case both
    }

    let parameters: DetectionParameters

    public init(parameters: DetectionParameters) {
        self.parameters = parameters
    }

    /// - Parameters:
    ///   - staff: the staff whose middle two spaces are searched for dots. Repeat dots
    ///     are engraved per-staff, so for a multi-staff System (e.g. grand staff) callers
    ///     should call this once per staff and merge results if they want dots detected
    ///     regardless of which staff carries them; for a single staff (typical lead
    ///     sheet / tab) there's nothing to merge.
    ///   - barlineXPositions: x-centers of already-detected barlines to test.
    ///   - allBarlineXPositionsInSystem: every barline x-center in the same System,
    ///     including ones not eligible for repeat-dot testing themselves (e.g.
    ///     `barlineXPositions` again if the caller has nothing more specific). Used
    ///     only to keep one barline's own dot search from sampling a NEIGHBORING
    ///     barline's ink (see the double-barline note below); defaults to
    ///     `barlineXPositions` for callers that don't have a fuller list handy.
    /// - Returns: for each barline x-center that has adjacent repeat dots, which side
    ///   they were found on. Barlines with no dots are omitted from the result.
    public func detectRepeats(
        in image: GrayscaleImage,
        staff: StaffLineDetector.Staff,
        barlineXPositions: [Int],
        allBarlineXPositionsInSystem: [Int]? = nil,
        skipLeftSearchAt leadingBarlineX: Int? = nil
    ) -> [Int: RepeatSide] {
        guard staff.lines.count >= 5, image.width > 0, image.height > 0 else { return [:] }
        let spacing = staff.spacing
        guard spacing > 0 else { return [:] }
        let allBarlineXs = allBarlineXPositionsInSystem ?? barlineXPositions

        // Repeat dots sit in the 2nd and 3rd spaces (0-indexed line pairs 1-2 and 2-3),
        // one dot centered in each, straddling the middle staff line.
        let gapRowA = (staff.lines[1] + staff.lines[2]) / 2
        let gapRowB = (staff.lines[2] + staff.lines[3]) / 2
        // The top and bottom spaces, used only as a "this x is NOT a tall glyph" check
        // (see isDot below) -- a clef, key signature or time signature typically spans
        // most or all of the staff height, while a genuine isolated dot pair is short
        // and sits only in the two middle spaces with clean space above and below it.
        let gapRowTop = (staff.lines[0] + staff.lines[1]) / 2
        let gapRowBottom = (staff.lines[3] + staff.lines[4]) / 2

        // A dot's own sampling window. This used to be sized as a fraction of a full
        // staff-space (spacing * 0.25 / 0.35), tuned against an engraving whose printed
        // repeat dots are close to that big. Not every notation renderer draws them that
        // large -- on a denser/smaller-engraved chart the dot can be well under half a
        // staff-space across, and a window sized for the bigger dot then always samples
        // mostly whitespace around a genuine small dot, so its measured coverage never
        // clears the coverage-ratio bar below no matter how solid the dot itself is.
        // Sized smaller (closer to the dot's own footprint) instead, which still comfortably
        // rejects wider glyphs (a sharp, a notehead) via the isolation/loneliness checks
        // below, which look just outside this window rather than depending on the window
        // itself being oversized.
        let halfStripHeight = max(1, Int((spacing * 0.18).rounded()))
        let dotHalfWidth = max(1, Int((spacing * 0.18).rounded()))

        // Dots sit close to the barline (roughly half a staff-space to ~1.5 staff-spaces
        // away, depending on engraving) -- search that whole band rather than one fixed
        // offset.
        let minOffset = max(1, Int((spacing * 0.25).rounded()))
        let maxOffsetBand = max(minOffset + 1, Int((spacing * 1.6).rounded()))
        let stepSize = max(1, dotHalfWidth)

        // A repeat barline is drawn as TWO strokes close together (thin+thick, a few
        // pixels apart) with the dots next to only one of them. When both strokes end up
        // as separate detected barline x-positions (they're often just far enough apart
        // not to get merged by BarlineDetector), naively searching outward from one of
        // them can sample the OTHER stroke itself -- a solid vertical line reads as
        // "fully dark" in a narrow dot-shaped window just as convincingly as a real dot
        // does, and can slip past the tall-glyph rejection too (that check uses a wider
        // window that a thin second stroke doesn't fill enough of to trip it). The result
        // is a barline mistaking its own paired stroke for a repeat dot on the wrong side.
        // Guarding against this directly -- never treat a point within this margin of a
        // DIFFERENT barline as dot ink, in either the main search or the loneliness probe
        // below -- fixes that regardless of how close together the two strokes happen to
        // render.
        let barlineExclusionMargin = max(dotHalfWidth + 1, Int((spacing * 0.4).rounded()))
        func isNearOtherBarline(_ x: Int, excluding originBarlineX: Int) -> Bool {
            for otherX in allBarlineXs where otherX != originBarlineX {
                if abs(x - otherX) <= barlineExclusionMargin { return true }
            }
            return false
        }

        // Like isNearOtherBarline, but ALSO counts the origin barline itself, using a
        // wider margin around it. A genuine repeat dot sits close to its own barline by
        // definition (that's the point of the dot -- it marks which barline the repeat
        // is at), so when the neighbor-count probe below samples a point that lands back
        // on the origin barline's own ink, that ink is not "another dot-shaped symbol
        // nearby" and must not be counted as one.
        //
        // The margin around the origin is wider than barlineExclusionMargin (used for
        // OTHER barlines) because a repeat barline is physically drawn as TWO strokes
        // (thin+thick) a bit under a staff-space apart -- see the double-barline note
        // above. When BarlineDetector's own merge distance collapses both strokes into a
        // single reported x (as it does here: only 1688 is reported even though the
        // second, thicker stroke's ink is real and sits ~11-12px further out), that
        // second stroke's own solid ink has no separate barline entry in allBarlineXs to
        // be excluded by, and reads as a same-looking neighbor almost as convincingly as
        // the real dot pair does. Widening the origin's own exclusion margin to comfortably
        // cover that companion stroke (roughly 1.3 staff-spaces) fixes this regardless of
        // whether BarlineDetector happens to merge the two strokes or not, without
        // touching the exclusion margin used for genuinely OTHER, unrelated barlines.
        let originCompanionMargin = max(barlineExclusionMargin, Int((spacing * 1.3).rounded()))
        func isNearAnyBarline(_ x: Int, originBarlineX: Int) -> Bool {
            if abs(x - originBarlineX) <= originCompanionMargin { return true }
            for otherX in allBarlineXs where otherX != originBarlineX {
                if abs(x - otherX) <= barlineExclusionMargin { return true }
            }
            return false
        }

        func darkRatio(aroundY y: Int, xCenter: Int, halfWidth: Int, halfHeight: Int? = nil) -> Double? {
            let halfHeight = halfHeight ?? halfStripHeight
            guard y - halfHeight >= 0, y + halfHeight < image.height else { return nil }
            guard xCenter - halfWidth >= 0, xCenter + halfWidth < image.width else { return nil }
            var darkCount = 0
            var total = 0
            for dx in -halfWidth...halfWidth {
                for dy in -halfHeight...halfHeight {
                    total += 1
                    if image.value(x: xCenter + dx, y: y + dy) < parameters.darkPixelThreshold {
                        darkCount += 1
                    }
                }
            }
            guard total > 0 else { return nil }
            return Double(darkCount) / Double(total)
        }

        // A staff space runs from one line to the next, roughly `spacing` pixels tall.
        // Used only by the compactness check below to sample close to the full height
        // of the space (but staying just inside the bounding lines).
        let fullSpaceHalfHeight = max(halfStripHeight + 1, Int((spacing * 0.42).rounded()))

        // A dot's own footprint plus, just outside it on either side, a thin probe
        // column used to confirm the dot sits in clear whitespace -- standard engraving
        // never butts a dot up against another symbol, so a genuine dot has a visible
        // gap on both sides of it, while a false match inside a wider glyph (a key
        // signature's sharps, a clef, a beam, a rest) does not: the ink there keeps
        // going past the dot-sized window instead of stopping.
        let isolationGap = max(1, Int((spacing * 0.05).rounded()))
        let isolationProbeHalfWidth = 1

        func isDot(xCenter: Int, originBarlineX: Int) -> Bool {
            guard xCenter - dotHalfWidth >= 0, xCenter + dotHalfWidth < image.width else { return false }
            if isNearOtherBarline(xCenter, excluding: originBarlineX) { return false }
            guard let middleA = darkRatio(aroundY: gapRowA, xCenter: xCenter, halfWidth: dotHalfWidth),
                  let middleB = darkRatio(aroundY: gapRowB, xCenter: xCenter, halfWidth: dotHalfWidth)
            else { return false }
            // Both middle spaces must show a dark blob at the same x -- a single dark
            // space alone is too easily a beam, slur, or note head passing through.
            // Threshold raised from 0.55 -> 0.65 (2026-09-29): a real repeat dot measured
            // on-device came in at 0.84/0.84, while a false match on an ordinary notehead/
            // accidental near a barline measured 0.60/0.60 -- comfortably below a genuine
            // dot's coverage but just over the old 0.55 bar. 0.65 sits clearly between the
            // two, rejecting the false positive without touching the real dot.
            guard middleA >= 0.65, middleB >= 0.65 else { return false }

            // Compactness check: a genuine repeat dot is small and round, sized well
            // under a full staff-space -- it sits centered in its space with a clear
            // margin of whitespace before the bounding lines above and below it. A dense
            // chord's notehead (or two adjacent noteheads a step apart) can land square
            // in the two middle spaces and read as high-coverage in the same narrow
            // center window a dot would, but it fills close to the FULL height of the
            // space, right up to the lines, because a notehead is drawn close to a full
            // staff-space tall. Re-measuring the same x with a much taller window (near
            // the full space height instead of the dot's own small footprint) and
            // requiring it to be noticeably LESS full than the compact measurement
            // catches that: coverage stays high for a dot's tiny footprint but visibly
            // drops once the window reaches toward the space's edges, while a notehead
            // stays just as packed either way.
            let fullA = darkRatio(aroundY: gapRowA, xCenter: xCenter, halfWidth: dotHalfWidth, halfHeight: fullSpaceHalfHeight) ?? 1
            let fullB = darkRatio(aroundY: gapRowB, xCenter: xCenter, halfWidth: dotHalfWidth, halfHeight: fullSpaceHalfHeight) ?? 1
            guard fullA <= 0.6, fullB <= 0.6 else { return false }

            // A clef, key signature or time signature glyph at this x would also make
            // the top and/or bottom space dark here (they're tall), which a genuine
            // isolated dot pair would not. This check turned out too easily tripped by
            // ordinary nearby content (beams, volta-bracket ticks) sitting right above or
            // below a genuine dot, killing real detections -- so it's loosened to a much
            // higher bar (mostly-solid ink, not just "somewhat dark"). Checked on BOTH
            // sides now, not just the bottom: a key signature's sharps are tall enough to
            // fill whichever outer space they lean toward (some sit high, some sit low
            // relative to the staff), and only checking the bottom space let a
            // high-sitting sharp slip through and get mistaken for a repeat dot right next
            // to a clef/key-signature glyph.
            let glyphCheckHalfWidth = dotHalfWidth * 2
            let bottomDark = darkRatio(aroundY: gapRowBottom, xCenter: xCenter, halfWidth: glyphCheckHalfWidth) ?? 0
            let topDark = darkRatio(aroundY: gapRowTop, xCenter: xCenter, halfWidth: glyphCheckHalfWidth) ?? 0
            guard bottomDark < 0.6, topDark < 0.6 else { return false }

            // Isolation check: just past the dot's own width on each side, the middle
            // gaps should go noticeably quieter. A wider glyph (sharps in a key
            // signature, a clef's curve, a beam) stays dark past that point; a genuine
            // isolated dot does not.
            // Probed at two distances out (right at the dot's edge, and a bit further)
            // so a glyph whose ink happens to thin out for a pixel or two right past the
            // dot -- as a sharp's lattice of strokes can, since sharps aren't solid --
            // doesn't slip through on a single lucky gap.
            func isolationFails(direction: Int) -> Bool {
                for step in 1...2 {
                    let probeX = xCenter + direction * (dotHalfWidth + isolationGap * step)
                    if isNearOtherBarline(probeX, excluding: originBarlineX) { continue }
                    let a = darkRatio(aroundY: gapRowA, xCenter: probeX, halfWidth: isolationProbeHalfWidth) ?? 0
                    let b = darkRatio(aroundY: gapRowB, xCenter: probeX, halfWidth: isolationProbeHalfWidth) ?? 0
                    if a >= 0.7, b >= 0.7 { return true }
                }
                return false
            }
            if isolationFails(direction: -1) || isolationFails(direction: 1) { return false }

            // A key signature is several sharps or flats standing shoulder to shoulder,
            // each one narrow enough that a single sharp can slip past the checks above
            // (it can be short enough to miss the top/bottom-space check, and the gaps
            // between adjacent sharps can be just wide enough to pass the immediate
            // isolation probes). What a lone repeat-dot pair never has, and a key
            // signature always does, is *several* other dot-shaped blobs strung out
            // across a wider band -- one per accidental. Count how many other x's in a
            // ~2.5-staff-space band on both sides also light up both middle spaces the
            // way this candidate does; a real dot pair stands alone, so more than a
            // couple of neighbors like that means this is a row of accidentals, not a
            // repeat dot. Points near another real barline are skipped here too -- that
            // barline's own stroke is not "another dot-like symbol nearby", and counting
            // it would make a lone genuine dot look like it has company it doesn't.
            let neighborCheckRadius = max(dotHalfWidth * 2, Int((spacing * 2.5).rounded()))
            let neighborStep = max(1, dotHalfWidth)
            var similarNeighborCount = 0
            var probeOffset = dotHalfWidth + isolationGap * 3
            while probeOffset <= neighborCheckRadius {
                for direction in [-1, 1] {
                    let probeX = xCenter + direction * probeOffset
                    // Excludes points near ANY barline, including this candidate's own
                    // origin barline (and its double-bar companion stroke) -- see
                    // isNearAnyBarline's doc comment above.
                    if isNearAnyBarline(probeX, originBarlineX: originBarlineX) { continue }
                    guard let a = darkRatio(aroundY: gapRowA, xCenter: probeX, halfWidth: dotHalfWidth),
                          let b = darkRatio(aroundY: gapRowB, xCenter: probeX, halfWidth: dotHalfWidth)
                    else { continue }
                    if a >= 0.5, b >= 0.5 { similarNeighborCount += 1 }
                }
                probeOffset += neighborStep
            }
            guard similarNeighborCount <= 1 else { return false }

            return true
        }

        func hasDots(direction: Int, from x: Int) -> Bool {
            // Never search past the midpoint to the nearest OTHER barline in that
            // direction -- past that point we'd only ever be looking at ink that belongs
            // to a neighboring barline (or, for a close double-barline pair, the SAME
            // repeat mark's other stroke), never a genuine dot for this one.
            var maxOffset = maxOffsetBand
            let nearestOther = allBarlineXs
                .filter { $0 != x && (direction > 0 ? $0 > x : $0 < x) }
                .min(by: { abs($0 - x) < abs($1 - x) })
            if let nearestOther {
                let halfway = max(minOffset, abs(nearestOther - x) / 2 - 1)
                maxOffset = min(maxOffset, halfway)
            }
            var offset = minOffset
            while offset <= maxOffset {
                if isDot(xCenter: x + direction * offset, originBarlineX: x) { return true }
                offset += stepSize
            }
            return false
        }

        var results: [Int: RepeatSide] = [:]
        for x in barlineXPositions {
            let right = hasDots(direction: 1, from: x)
            // The System's own leading barline (right after clef/key/time signature)
            // has nothing musically before it to end a repeat into -- searching left of
            // it only ever finds the signature glyphs themselves, never a real dot pair,
            // so skip that direction there entirely rather than risk a false positive.
            let left = (x == leadingBarlineX) ? false : hasDots(direction: -1, from: x)
            switch (left, right) {
            case (true, true): results[x] = .both
            case (false, true): results[x] = .start
            case (true, false): results[x] = .end
            case (false, false): break
            }
        }
        return results
    }
}
