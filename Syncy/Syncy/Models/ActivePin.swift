//
//  ActivePin.swift
//  Syncy
//
//  Created by anna on 10/22/26.
//

import Foundation

struct ActivePin: Equatable {
    var pinID: UUID
    var range: ClosedRange<TimeInterval>
    var sessionID: SessionID
}
