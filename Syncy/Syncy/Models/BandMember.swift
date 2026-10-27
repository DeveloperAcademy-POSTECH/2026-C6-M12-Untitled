//
//  BandMember.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

struct BandMember: Equatable {
    var person: Person
    var part: Part
    var isPending: Bool   // 초대 대기
}
