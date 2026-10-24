//
//  PinDraft.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

struct PinDraft: Equatable {
    var sessionID: SessionID
    var startTime: TimeInterval?
    var endTime: TimeInterval?
    
    var range: ClosedRange<TimeInterval>? {
        guard let start = startTime,
              let end = endTime,
              end > start else {
            return nil
        }
        return start ... end
    }
    
    var canConfirm: Bool {
        return range != nil
    }
}
