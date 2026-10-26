//
//  RecordingPhase.swift
//  Syncy
//
//  Created by anna on 10/22/26.
//

enum RecordingPhase: Equatable {
    case idle
    case requestingPermission
    case countIn(beat: Int)
    case recording
    case finishing
}
