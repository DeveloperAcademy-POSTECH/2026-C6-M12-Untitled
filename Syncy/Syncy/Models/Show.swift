//
//  Show.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

struct Show: Equatable, Identifiable {
    var id: UUID
    var name: String
    var startsAt: Date?
    var venue: String?
    var sessionIDs: [SessionID]   // 공연 세션을 유지할지 확인 필요 (칠판에 "곡 세션만 추가하기")
    // 함수 dDay(today)는 반환 타입 미정
}
