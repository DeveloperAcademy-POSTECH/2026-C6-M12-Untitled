//
//  RemoteState.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

/// 서버에서 받는 데이터 한 덩어리. version이 같으면 서버가 바뀌지 않은 것이다.
struct RemoteState: Equatable, Codable {
    var version: Int
    var songJobId: String?
    var songBPM: Double?
    var firstBeatOffset: TimeInterval?
    var feedback: [FeedbackItem]?
    var patches: [Patch]?
}
