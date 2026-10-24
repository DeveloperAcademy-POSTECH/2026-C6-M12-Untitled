//
//  RemoteState.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

struct RemoteState: Equatable, Codable {
    var version: Int
    var songJobId: String?
    var songBPM: Double?
    var firstBeatOffset: TimeInterval?
    var feedback: [FeedbackItem]?
    var patches: [Patch]?
}
