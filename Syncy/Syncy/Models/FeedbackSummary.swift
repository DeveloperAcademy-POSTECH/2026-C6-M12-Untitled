//
//  FeedbackSummary.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

struct FeedbackSummary: Equatable, Identifiable {
    var showName: String
    var songTitle: String
    var pinID: UUID
    var title: String
    var part: Part
    // 마디 범위, from → to는 타입 미정
    var status: FeedbackFeature.FeedbackStatus
    var updatedAt: Date
    var appliedVersion: Int?

    var id: UUID { pinID }
}
