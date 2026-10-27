//
//  PracticeSettings.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

/// 연습 설정. 설정 화면이 바꾸고, Player · Practice가 읽는다.
struct PracticeSettings: Equatable {
    var startRate: Float = 0.8
    // countInBars, metronomeSound, latencyCompensation(auto · ms), checkHeadphones, inputID는 타입 미정
}

// appStorage에 저장하려고 RawRepresentable로 만듦. 저장 모양은 미정
extension PracticeSettings: RawRepresentable {
    init?(rawValue: String) {
        guard let startRate = Float(rawValue) else { return nil }
        self.init(startRate: startRate)
    }

    var rawValue: String {
        String(startRate)
    }
}
