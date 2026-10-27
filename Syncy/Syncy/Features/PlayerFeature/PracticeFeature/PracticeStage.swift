//
//  PracticeStage.swift
//  Syncy
//
//  Created by martin on 10/27/26.
//

import Foundation

// 연습 1 → 녹음 2 → 어때? 3 흐름의 지금 단계. 바뀌는 시점은 미정
enum PracticeStage: Equatable, Sendable {
    case idle
    case countIn
    case looping(lap: Int, step: Int)   // 미정: 사다리를 뺀 뒤 step을 어떻게 할지
    case finished
    case recording
}
