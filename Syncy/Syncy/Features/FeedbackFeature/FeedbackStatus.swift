//
//  FeedbackStatus.swift
//  Syncy
//
//  Created by moo on 10/22/26.
//

extension FeedbackFeature {
    enum FeedbackStatus: Equatable {
        case idle
        case discussing // 이야기 중
        case applied    // 패치 등록됨 (파트별)
    }
}
