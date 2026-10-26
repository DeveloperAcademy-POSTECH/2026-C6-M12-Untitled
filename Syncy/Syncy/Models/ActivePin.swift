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

extension ActivePin {
    // Feedback의 기존 배열 입력을 받되, 파트가 하나인 핀만 연다.
    init?(pinID: UUID, range: ClosedRange<TimeInterval>, sessionIDs: [SessionID]) {
        guard sessionIDs.count == 1, let sessionID = sessionIDs.first else { return nil }
        self.init(pinID: pinID, range: range, sessionID: sessionID)
    }
}
