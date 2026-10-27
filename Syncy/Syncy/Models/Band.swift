//
//  Band.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

struct Band: Equatable, Identifiable {
    var id: UUID
    var name: String
    var photoURL: URL?
    var intro: String?
    var inviteCode: String   // 6자리
    var members: [BandMember]   // 멤버 수 제한 없음 (밴드 인원 20~30명을 생각하고 설계)
}
