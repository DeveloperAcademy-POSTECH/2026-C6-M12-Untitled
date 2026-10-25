//
//  FeedbackAttempt.swift
//  Syncy
//
//  Created by moo on 10/22/26.
//

import Foundation

struct FeedbackAttempt: Equatable, Codable {
    var id: UUID
    var author: Person       // 누구나
    var sessionId: SessionID
    var patchId: UUID
    var createdAt: Date
    var comments: [FeedbackComment]
}
