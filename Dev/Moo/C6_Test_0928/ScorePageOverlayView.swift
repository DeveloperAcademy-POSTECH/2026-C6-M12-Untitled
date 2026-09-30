import SwiftUI
import ScoreDetectCore

/// Renders one rasterized page with its detected System/Measure boxes overlaid, and
/// handles all direct interaction with the score: pinch-to-zoom/pan (so the page can
/// fill an iPad screen and still be readable up close), and tapping a measure, whose
/// meaning depends on the caller's mode: seek-and-play the synced audio in normal mode,
/// or extend a feedback range in selection mode.
///
/// Measure hit-testing is done via a single SpatialTapGesture on the container rather
/// than a per-measure `.onTapGesture`: a discrete tap gesture on a child view loses the
/// gesture race against the container's simultaneous DragGesture (used for panning) even
/// when both are declared `.simultaneousGesture` -- in practice the child tap never fires
/// while the parent's pan gesture still claims the touch. Hit-testing tap location against
/// the measures' own boxes sidesteps that conflict entirely.
struct ScorePageOverlayView: View {
    let cgImage: CGImage
    let page: DetectedPage?
    @Binding var selectedMeasureID: Int?
    var isSelectionMode: Bool = false
    @Binding var selectionRange: ClosedRange<Int>?
    var highlightedMeasureID: Int? = nil
    /// Which even beat-slice (0-based) of the highlighted measure playback is
    /// currently inside, per `AudioSyncSettings.measureAndBeat` -- an assumption-based
    /// approximation (measure divided evenly by beat count), not real rhythm
    /// detection. nil hides the beat-level marker (e.g. no audio loaded).
    var highlightedBeatIndex: Int? = nil
    /// How many equal beat-slices to divide a measure into when drawing beat
    /// dividers and hit-testing a tap's beat, taken straight from the current time
    /// signature (`AudioSyncSettings.beatsPerMeasure`).
    var beatsPerMeasure: Int = 4
    /// `(measure, beatIndex)` -- `beatIndex` is which even beat-slice (0-based) the
    /// tap landed in, left-to-right across the measure box.
    var onMeasureTapped: ((DetectedMeasure, Int) -> Void)? = nil

    @GestureState private var pinchScale: CGFloat = 1
    @State private var steadyZoom: CGFloat = 1
    @GestureState private var dragTranslation: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero

    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 6

    private var imageSize: CGSize {
        CGSize(width: cgImage.width, height: cgImage.height)
    }

    var body: some View {
        GeometryReader { geometry in
            let baseScale = min(
                geometry.size.width / imageSize.width,
                geometry.size.height / imageSize.height
            )
            let zoom = clamp(steadyZoom * pinchScale, lower: minZoom, upper: maxZoom)
            let scale = baseScale * zoom
            let displaySize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let originX = (geometry.size.width - displaySize.width) / 2 + steadyOffset.width + dragTranslation.width
            let originY = (geometry.size.height - displaySize.height) / 2 + steadyOffset.height + dragTranslation.height

            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: geometry.size.width, height: geometry.size.height)

                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .interpolation(.medium)
                    .frame(width: displaySize.width, height: displaySize.height)
                    .offset(x: originX, y: originY)
                    .allowsHitTesting(false)

                if let page {
                    ForEach(page.systems) { system in
                        Rectangle()
                            .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                            .frame(width: system.box.width * scale, height: system.box.height * scale)
                            .offset(x: originX + system.box.minX * scale, y: originY + system.box.minY * scale)
                            .allowsHitTesting(false)
                    }
                    ForEach(page.measures) { measure in
                        let state = measureState(measure)
                        Rectangle()
                            .fill(state.fillColor)
                            .overlay(Rectangle().stroke(state.strokeColor, lineWidth: state.lineWidth))
                            .frame(width: measure.box.width * scale, height: measure.box.height * scale)
                            .offset(x: originX + measure.box.minX * scale, y: originY + measure.box.minY * scale)
                            .allowsHitTesting(false)
                    }
                    // Repeat-barline markers (도돌이표): drawn separately from the plain
                    // green measure outline above so they read clearly regardless of
                    // selection/highlight state. Purple double-dot glyph at the measure
                    // edge that carries the repeat, dots facing into the measure they
                    // belong to (matches standard engraving: |: dots face right, :| dots
                    // face left).
                    ForEach(page.measures.filter { $0.hasRepeatStart }) { measure in
                        repeatMarkView(
                            atX: measure.box.minX, top: measure.box.minY, height: measure.box.height,
                            dotsToRight: true, scale: scale, originX: originX, originY: originY
                        )
                    }
                    ForEach(page.measures.filter { $0.hasRepeatEnd }) { measure in
                        repeatMarkView(
                            atX: measure.box.maxX, top: measure.box.minY, height: measure.box.height,
                            dotsToRight: false, scale: scale, originX: originX, originY: originY
                        )
                    }
                    // Beat-level detail: only drawn on the currently-highlighted measure
                    // (drawing this on every measure would be visual noise). Splits the
                    // measure box into `beatsPerMeasure` equal slices -- an assumption,
                    // not detected rhythm -- and darkens the slice playback is in right now.
                    if let highlightedMeasureID,
                       let measure = page.measures.first(where: { $0.id == highlightedMeasureID }),
                       beatsPerMeasure > 1 {
                        beatOverlay(for: measure, scale: scale, originX: originX, originY: originY)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(magnifyGesture)
            .simultaneousGesture(panGesture)
            .simultaneousGesture(measureTapGesture(originX: originX, originY: originY, scale: scale))
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                withAnimation(.spring(response: 0.3)) {
                    steadyZoom = 1
                    steadyOffset = .zero
                }
            })
            .clipped()
        }
    }

    private struct MeasureVisualState {
        let strokeColor: Color
        let fillColor: Color
        let lineWidth: CGFloat
    }

    private func measureState(_ measure: DetectedMeasure) -> MeasureVisualState {
        if let selectionRange, selectionRange.contains(measure.id) {
            return MeasureVisualState(strokeColor: .orange, fillColor: Color.orange.opacity(0.22), lineWidth: 2)
        }
        if measure.id == highlightedMeasureID {
            return MeasureVisualState(strokeColor: .yellow, fillColor: Color.yellow.opacity(0.28), lineWidth: 2.5)
        }
        if measure.id == selectedMeasureID {
            return MeasureVisualState(strokeColor: .red, fillColor: Color.red.opacity(0.15), lineWidth: 2)
        }
        return MeasureVisualState(strokeColor: Color.green.opacity(0.7), fillColor: .clear, lineWidth: 1)
    }

    /// A vertical purple bar plus two stacked dots at the barline `x` (image/point
    /// space) that carries a repeat, dots on the side of the measure they belong to.
    /// This is a UI affordance, not a redraw of the exact detected dot pixels -- it's
    /// meant to be glanceable at any zoom level, not pixel-accurate to the engraving.
    @ViewBuilder
    private func repeatMarkView(
        atX x: CGFloat, top: CGFloat, height: CGFloat, dotsToRight: Bool,
        scale: CGFloat, originX: CGFloat, originY: CGFloat
    ) -> some View {
        let barWidth = max(2, 3 * scale)
        let dotDiameter = max(3, 5 * scale)
        let dotOffset = max(4, 8 * scale) * (dotsToRight ? 1 : -1)
        let barHeight = height * scale
        ZStack {
            Rectangle()
                .fill(Color.purple)
                .frame(width: barWidth, height: barHeight)
            Circle()
                .fill(Color.purple)
                .frame(width: dotDiameter, height: dotDiameter)
                .offset(x: dotOffset, y: -barHeight * 0.14)
            Circle()
                .fill(Color.purple)
                .frame(width: dotDiameter, height: dotDiameter)
                .offset(x: dotOffset, y: barHeight * 0.14)
        }
        .frame(width: barWidth, height: barHeight)
        .offset(x: originX + x * scale - barWidth / 2, y: originY + top * scale)
        .allowsHitTesting(false)
    }

    /// Draws thin dividers splitting `measure`'s box into `beatsPerMeasure` equal
    /// slices, plus a stronger fill over whichever slice `highlightedBeatIndex`
    /// currently is. Only ever called for the one measure currently playing, so this
    /// doesn't clutter the rest of the page.
    @ViewBuilder
    private func beatOverlay(for measure: DetectedMeasure, scale: CGFloat, originX: CGFloat, originY: CGFloat) -> some View {
        let box = measure.box
        let beatWidth = box.width / CGFloat(beatsPerMeasure)
        ForEach(1..<beatsPerMeasure, id: \.self) { i in
            Rectangle()
                .fill(Color.yellow.opacity(0.5))
                .frame(width: 1, height: box.height * scale)
                .offset(x: originX + (box.minX + CGFloat(i) * beatWidth) * scale, y: originY + box.minY * scale)
                .allowsHitTesting(false)
        }
        if let highlightedBeatIndex, beatsPerMeasure > 0 {
            Rectangle()
                .fill(Color.orange.opacity(0.35))
                .frame(width: beatWidth * scale, height: box.height * scale)
                .offset(
                    x: originX + (box.minX + CGFloat(highlightedBeatIndex) * beatWidth) * scale,
                    y: originY + box.minY * scale
                )
                .allowsHitTesting(false)
        }
    }

    private func handleTap(on measure: DetectedMeasure, beatIndex: Int) {
        if isSelectionMode {
            // Selecting a feedback range is measure-granular by design (a feedback
            // note is written against whole measures), so the beat the tap happened
            // to land on doesn't matter here.
            if let range = selectionRange {
                let lower = min(range.lowerBound, measure.id)
                let upper = max(range.upperBound, measure.id)
                selectionRange = lower...upper
            } else {
                selectionRange = measure.id...measure.id
            }
        } else {
            selectedMeasureID = (selectedMeasureID == measure.id) ? nil : measure.id
            onMeasureTapped?(measure, beatIndex)
        }
    }

    /// Which even beat-slice (0-based, left-to-right) of `box` the x-coordinate
    /// `x` (image/point space) falls into, assuming the measure's beats are spaced
    /// evenly across its width. Not real rhythm detection -- just the same
    /// even-division assumption `AudioSyncSettings` uses for time, applied to the
    /// measure's on-page geometry instead of its audio duration.
    private func beatIndex(forX x: CGFloat, in box: CGRect) -> Int {
        guard beatsPerMeasure > 1, box.width > 0 else { return 0 }
        let fraction = (x - box.minX) / box.width
        let clamped = min(max(fraction, 0), 0.999)
        return Int(clamped * CGFloat(beatsPerMeasure))
    }

    /// A single tap anywhere in the container is hit-tested against each measure's own
    /// box (converted from image/point space to this view's on-screen space using the
    /// same origin/scale the boxes are drawn with) rather than relying on a per-measure
    /// `.onTapGesture`, which loses the gesture race against `panGesture` (see the type's
    /// doc comment above).
    private func measureTapGesture(originX: CGFloat, originY: CGFloat, scale: CGFloat) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard let page else { return }
                let localX = (value.location.x - originX) / scale
                let localY = (value.location.y - originY) / scale
                let point = CGPoint(x: localX, y: localY)
                if let measure = page.measures.first(where: { $0.box.contains(point) }) {
                    handleTap(on: measure, beatIndex: beatIndex(forX: point.x, in: measure.box))
                }
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in state = value }
            .onEnded { value in
                steadyZoom = clamp(steadyZoom * value, lower: minZoom, upper: maxZoom)
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragTranslation) { value, state, _ in state = value.translation }
            .onEnded { value in
                steadyOffset.width += value.translation.width
                steadyOffset.height += value.translation.height
            }
    }
}

private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
    min(max(value, lower), upper)
}
