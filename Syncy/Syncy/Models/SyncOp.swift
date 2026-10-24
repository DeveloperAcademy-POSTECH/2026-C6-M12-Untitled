//
//  SyncOp.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

/// 서버에 보낼 변경 하나. Feedback이 만들고, Sync가 순서대로 보낸다.
/// 글(comment)은 핀에 달리거나 녹음 답에 달리므로 attemptID가 있으면 그 녹음 답의 글이다.
enum SyncOp: Equatable, Codable {
    case feedbackAdded(FeedbackItem)
    case feedbackDeleted(id: UUID)
    case attemptAdded(FeedbackAttempt, feedbackID: UUID)
    case attemptDeleted(id: UUID, feedbackID: UUID)
    case commentAdded(FeedbackComment, feedbackID: UUID, attemptID: UUID?)
    case commentDeleted(id: UUID, feedbackID: UUID, attemptID: UUID?)
    case patchUpserted(Patch)
    case patchDeleted(id: UUID)
}
