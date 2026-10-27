//
//  SongDraft.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

struct SongDraft: Equatable {
    var title: String
    var artist: String?
    var fileURL: URL
    var sessionIDs: [SessionID]
    var showID: UUID
    var bpm: Double
    var firstBeatOffset: TimeInterval
    // 세션별 담당자 (10/27)는 필드 이름 · 타입 · 저장 위치 미정
}
