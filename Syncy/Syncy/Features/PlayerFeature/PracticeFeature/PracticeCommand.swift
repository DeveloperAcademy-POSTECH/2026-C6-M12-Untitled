//
//  PracticeCommand.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

// Practice가 부모 Player에게 보내는 재생 명령. Practice.delegate.playback으로 보내고, Player가 직접 처리한다.
enum PracticeCommand: Equatable, Sendable {
    case loop(ClosedRange<TimeInterval>?)   // nil이면 반복 끔
    case rate(Float)                        // 연습 템포
    case stop                               // 보내는 시점 미정
}
