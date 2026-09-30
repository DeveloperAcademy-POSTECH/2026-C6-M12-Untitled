import Foundation

/// Turns a global tempo (BPM) and time signature into a start time for every measure
/// in the piece, so the whole score can be mapped onto an audio recording from just
/// three numbers instead of tagging each measure by hand. This assumes a constant
/// tempo and a constant beats-per-measure across the whole piece -- a simplification
/// that will drift on pieces with tempo changes, rubato, or mixed meters, but gives a
/// genuinely automatic starting point (no per-measure tagging) that a small BPM or
/// offset correction can then straighten out.
///
/// The mapping is no longer a flat "measure index * seconds-per-measure" -- a real
/// recording plays a repeated section twice, so the *time* a given written measure
/// sounds at, and the *written measure* sounding at a given time, both depend on
/// where any 도돌이표 (repeat barlines) fall. See `PlaybackSequence` below.
public struct AudioSyncSettings: Codable, Equatable {
    public var bpm: Double
    public var beatsPerMeasure: Double
    /// Seconds into the audio file where measure #0 (the very first measure of the
    /// piece) begins -- i.e. how far in any lead-in/count-off/silence runs.
    public var startOffsetSeconds: Double

    public init(bpm: Double = 120, beatsPerMeasure: Double = 4, startOffsetSeconds: Double = 0) {
        self.bpm = bpm
        self.beatsPerMeasure = beatsPerMeasure
        self.startOffsetSeconds = startOffsetSeconds
    }

    private var secondsPerMeasure: Double? {
        guard bpm > 0, beatsPerMeasure > 0 else { return nil }
        return (beatsPerMeasure * 60.0) / bpm
    }

    /// A measure split into `beatsPerMeasure` equal slices -- not real rhythm
    /// detection, just "assume every beat takes the same amount of time", which is
    /// exactly true for a measure of plain quarter notes and only approximate
    /// otherwise (a measure with an eighth-note run or a dotted rhythm will have
    /// beats that don't actually land on these boundaries). Still strictly more
    /// precise than resolving to "somewhere in this measure", since the time
    /// signature is already known and free to use.
    private var secondsPerBeat: Double? {
        guard let secondsPerMeasure, beatsPerMeasure > 0 else { return nil }
        return secondsPerMeasure / beatsPerMeasure
    }

    /// How many even beat-slices a measure is divided into for `beatIndex`
    /// clamping, e.g. 4 for a 4/4-style `beatsPerMeasure` of 4.0.
    private var beatCount: Int {
        max(1, Int(beatsPerMeasure.rounded(.down)))
    }

    /// Seconds into the audio where the measure at `globalIndex` (0-based, counting
    /// every measure in piece-*reading* order across every page -- i.e. its position
    /// on the page, not the order it's actually played in) begins, optionally offset
    /// by `beatIndex` (0-based) even-beat-slices into that measure -- see
    /// `secondsPerBeat`'s doc comment for what that assumption does and doesn't buy.
    ///
    /// When `orderedMeasures` carries repeat-barline info (see `ScoreDetectCore`'s
    /// repeat detection), this follows the repeat: a measure inside a repeated
    /// section maps to the time of its *first* performance, and every measure after
    /// the repeat is pushed later by however long the repeated material takes to
    /// play again. Pass `orderedMeasures: []` (or measures with no repeat flags set)
    /// to fall back to the old flat "reading order == playback order" assumption.
    public func startTime(forGlobalMeasureIndex globalIndex: Int, beatIndex: Int = 0, in orderedMeasures: [OrderedMeasure] = []) -> Double? {
        guard let secondsPerMeasure else { return nil }
        let measureStart: Double
        if orderedMeasures.isEmpty {
            measureStart = startOffsetSeconds + Double(globalIndex) * secondsPerMeasure
        } else {
            let sequence = PlaybackSequence.build(from: orderedMeasures)
            guard let slot = sequence.firstIndex(of: globalIndex) else {
                // Should only happen for an out-of-range index (past the last measure) --
                // fall back to the flat assumption rather than returning nil, so a tap
                // still does *something* close to right instead of silently no-op'ing.
                measureStart = startOffsetSeconds + Double(globalIndex) * secondsPerMeasure
                return measureStart
            }
            measureStart = startOffsetSeconds + Double(slot) * secondsPerMeasure
        }
        guard let secondsPerBeat else { return measureStart }
        let clampedBeat = max(0, min(beatIndex, beatCount - 1))
        return measureStart + Double(clampedBeat) * secondsPerBeat
    }

    /// The 0-based global (reading-order) measure index playing at `time`, or nil if
    /// `time` is before the first measure, after the last one, or the tempo hasn't
    /// been set up yet. See `startTime(forGlobalMeasureIndex:in:)` for how repeats
    /// are folded in -- this is its inverse, and is what actually benefits the most
    /// from repeat-awareness, since it's what drives the "now playing" highlight
    /// during playback: without it, the highlight would march straight past the
    /// repeated section on the first pass and be permanently out of sync for the
    /// rest of the piece.
    public func globalMeasureIndex(atTime time: Double, in orderedMeasures: [OrderedMeasure]) -> Int? {
        measureAndBeat(atTime: time, in: orderedMeasures)?.globalIndex
    }

    /// Same lookup as `globalMeasureIndex(atTime:in:)`, but also returns which
    /// even beat-slice (0-based, see `secondsPerBeat`) `time` falls into within that
    /// measure -- an assumption-based approximation, not real rhythm detection, but
    /// still a strictly finer answer than "somewhere in this measure" given that the
    /// time signature is already known.
    public func measureAndBeat(atTime time: Double, in orderedMeasures: [OrderedMeasure]) -> (globalIndex: Int, beatIndex: Int)? {
        guard !orderedMeasures.isEmpty, let secondsPerMeasure, let secondsPerBeat else { return nil }
        let elapsed = time - startOffsetSeconds
        guard elapsed >= 0 else { return nil }
        let sequence = PlaybackSequence.build(from: orderedMeasures)
        guard !sequence.isEmpty else { return nil }
        let slot = Int(elapsed / secondsPerMeasure)
        guard slot < sequence.count else { return nil }
        let intoMeasure = elapsed - Double(slot) * secondsPerMeasure
        let beatIndex = max(0, min(Int(intoMeasure / secondsPerBeat), beatCount - 1))
        return (sequence[slot], beatIndex)
    }

    /// Old flat-measure-count entry point, kept for callers that don't have repeat
    /// info handy. Equivalent to calling the repeat-aware overload with no repeats.
    public func globalMeasureIndex(atTime time: Double, measureCount: Int) -> Int? {
        guard measureCount > 0, let secondsPerMeasure else { return nil }
        let elapsed = time - startOffsetSeconds
        guard elapsed >= 0 else { return nil }
        let index = Int(elapsed / secondsPerMeasure)
        guard index < measureCount else { return nil }
        return index
    }
}

/// Expands piece-reading-order measures into performance order by walking forward
/// and, on reaching a measure whose repeat barline hasn't been taken yet, jumping
/// back to the nearest preceding repeat-start (or the very beginning, if the
/// repeated section has no explicit start dots -- "repeat from the top" is common
/// and legitimate). Each repeat-end is only ever taken once, so a `:|:` (repeat end
/// immediately followed by a new repeat start) still terminates normally rather than
/// looping.
///
/// This intentionally does not know about 1st/2nd-ending (volta) brackets -- they
/// aren't detected (see `RepeatBarlineDetector`), so the second pass through a
/// repeated section is approximated as playing the *same* measures again rather than
/// skipping into a different ending. That's exactly right for a plain repeat with no
/// endings, and only drifts for the handful of measures right around a volta bracket
/// on a piece that has one -- still a large improvement over ignoring repeats
/// entirely, which desyncs everything from the first repeat onward.
enum PlaybackSequence {
    /// `result[playbackSlot] == the written (reading-order) global measure index
    /// sounding during that slot`. `result.count >= orderedMeasures.count` whenever
    /// at least one repeat is present, since repeated measures appear more than once.
    static func build(from orderedMeasures: [OrderedMeasure]) -> [Int] {
        let count = orderedMeasures.count
        guard count > 0 else { return [] }
        let hasRepeatStart = orderedMeasures.map { $0.measure.hasRepeatStart }
        let hasRepeatEnd = orderedMeasures.map { $0.measure.hasRepeatEnd }

        var sequence: [Int] = []
        var takenRepeatEnds = Set<Int>()
        var current = 0
        // A generous but finite cap: with each repeat-end only ever taken once,
        // the true worst case is well under 2x the measure count, but this leaves
        // headroom without risking a runaway loop on unexpected input.
        let maxSteps = count * 4
        var steps = 0
        while current < count, steps < maxSteps {
            sequence.append(current)
            steps += 1
            if hasRepeatEnd[current], !takenRepeatEnds.contains(current) {
                takenRepeatEnds.insert(current)
                var jumpTo = 0
                var i = current
                while i >= 0 {
                    if hasRepeatStart[i] { jumpTo = i; break }
                    i -= 1
                }
                current = jumpTo
                continue
            }
            current += 1
        }
        return sequence
    }
}
