//
//  RecordingTarget.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

struct RecordingTarget: Equatable {
    var pinID: UUID
    var range: ClosedRange<TimeInterval>
    var sessionID: SessionID
}
