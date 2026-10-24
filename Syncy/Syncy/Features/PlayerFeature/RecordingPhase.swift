//
//  RecordingPhase.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

enum RecordingPhase: Equatable {
    case idle
    case countIn(beat: Int)
    case recording
    case finishing
}
