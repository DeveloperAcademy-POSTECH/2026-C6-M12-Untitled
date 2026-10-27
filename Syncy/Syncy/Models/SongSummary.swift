//
//  SongSummary.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

struct SongSummary: Equatable, Identifiable {
    var songID: String
    var title: String
    var artist: String?
    var order: Int
    var sessionIDs: [SessionID]
    var status: SongStatus
    // counts(이야기 · 연습 · 반영)는 타입 미정

    var id: String { songID }
}

enum SongStatus: Equatable {
    case adding
    case ready
    case failed
}
