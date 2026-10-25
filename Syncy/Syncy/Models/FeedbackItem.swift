//
//  FeedbackItem.swift
//  Syncy
//
//  Created by moo on 10/22/26.
//

import ComposableArchitecture
import Foundation

struct FeedbackItem: Equatable, Identifiable, Codable {
    var id: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var createdAt: Date
    var text: String
    var author: Person  // 핀 쓴 사람
    var translations: [String: String]?
    var targetSessionIds: [SessionID]
    var attempts: [FeedbackAttempt]
    var comments: [FeedbackComment]
    
    // 작성자만 지울 수 있음
    func canDelete(by person: Person) -> Bool {
        author.id == person.id
    }
    
    // 판정 로직 미정: 일단 해당 파트의 패치가 등록됐으면 .applied
    // 우선 목데이터
    func status(for sessionID: SessionID, patches: IdentifiedArrayOf<Patch>) -> FeedbackFeature.FeedbackStatus {
        return .discussing
    }
    
    // 계산 방법 미정, 일단 마지막 댓글 쓴 사람
    // createdAt으로 정렬해도 될 듯? 아니면 댓글 달 때마다 업데이트
    var lastSpeaker: Person? {
        comments.last?.author
    }
    
    var timeRange: ClosedRange<TimeInterval> {
        startTime...endTime
    }
}
