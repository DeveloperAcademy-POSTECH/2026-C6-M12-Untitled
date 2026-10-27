//
//  FeedbackQueryClient.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct FeedbackQueryClient {
    var todos: (_ me: Person) async throws -> [TodoItem]
    // 인자 tab 타입 미정
    var allFeedback: (_ bandID: UUID) async throws -> [FeedbackSummary]
}

// liveValue는 Service에 일을 넘기기만 한다.
extension FeedbackQueryClient: DependencyKey {
    static let liveValue: FeedbackQueryClient = {
        let service = FeedbackQueryService()
        return Self(
            todos: { me in
                try await service.todos(me: me)
            },
            allFeedback: { bandID in
                try await service.allFeedback(bandID: bandID)
            }
        )
    }()

    // 목데이터 Service라서 previewValue는 liveValue와 같음. 진짜 조회가 구현되면 분리
    static let previewValue = liveValue
    static let testValue = Self()
}

extension DependencyValues {
    var feedbackQueryClient: FeedbackQueryClient {
        get { self[FeedbackQueryClient.self] }
        set { self[FeedbackQueryClient.self] = newValue }
    }
}
