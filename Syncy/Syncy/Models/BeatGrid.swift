//
//  BeatGrid.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

struct BeatGrid: Equatable {
    var bpm: Double
    var firstBeatOffset: TimeInterval
    var beatsPerBar: Int = 4
    
    func position(at time: TimeInterval) -> MusicalPosition {
        precondition(bpm.isFinite && bpm > 0, "BPM은 유효한 양수")
        precondition(beatsPerBar == 4, "한 마디에 4박")
        precondition(time.isFinite, "시간은 유효한 숫자")

        let secondsPerBeat = 60.0 / bpm // 한 박의 길이(초)
        let elapsedTime = max(0, time - firstBeatOffset) // 첫 박부터 지난 시간(초)
        let elapsedBeats = elapsedTime / secondsPerBeat // 지난 박 수(소수 포함)
        let totalBeats = Int(elapsedBeats + 0.000000001) // 오차를 보정한 정수 박 수

        let measure = totalBeats / beatsPerBar + 1
        let beat = totalBeats % beatsPerBar + 1

        return MusicalPosition(measure: measure, beat: beat)
    }

    func time(of position: MusicalPosition) -> TimeInterval {
        precondition(bpm.isFinite && bpm > 0, "BPM은 유효한 양수")
        precondition(beatsPerBar == 4, "현재 설계는 한 마디 4박입니다.")

        let secondsPerBeat = 60.0 / bpm

        // 해당 마디·박 앞에 있는 박의 개수
        let totalBeats = (position.measure - 1) * beatsPerBar
            + (position.beat - 1)

        return firstBeatOffset + Double(totalBeats) * secondsPerBeat
    }
}

struct MusicalPosition: Equatable {
    let measure: Int
    let beat: Int
    
    init(measure: Int, beat: Int) {
        precondition(measure >= 1, "마디는 1 이상")
        precondition((1...4).contains(beat), "박은 1~4 이내")
        
        self.measure = measure
        self.beat = beat
    }
}
