//
//  Patch.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

nonisolated struct Patch: Equatable, Identifiable {
    var id: UUID
    var sessionId: SessionID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var createdAt: Date
    var sourceStart: TimeInterval
    var isAdopted: Bool
    
    var timeRange: ClosedRange<TimeInterval> {
        return startTime...endTime
    }

    var duration: TimeInterval {
        return endTime - startTime
    }
}
