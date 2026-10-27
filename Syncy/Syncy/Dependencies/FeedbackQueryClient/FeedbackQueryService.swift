//
//  FeedbackQueryService.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

// 홈에서 보는 "지금 할 일"과 밴드 전체 피드백을 모아 주는 곳. FeedbackQueryClient의 liveValue가 이걸 부름.
// 일단 전부 목데이터로
struct FeedbackQueryService: Sendable {
    func todos(me: Person) async throws -> [TodoItem] {
        try? await Task.sleep(for: .milliseconds(500))
        return []   // 목데이터: 할 일 없음
    }

    func allFeedback(bandID: UUID) async throws -> [FeedbackSummary] {
        try? await Task.sleep(for: .milliseconds(500))
        return []   // 목데이터: 피드백 없음
    }
}
