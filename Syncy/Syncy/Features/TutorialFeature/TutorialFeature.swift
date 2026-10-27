//
//  TutorialFeature.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct TutorialFeature {
    @ObservableState
    struct State: Equatable {
        var step: Int?
        @Shared(.tutorialDone) var tutorialDone: Bool
        @Shared(.pinDraft) var pinDraft: PinDraft?   // 읽기만
    }

    // 코치마크 4단계: 내 트랙 → 끌어서 구간 → 첫 말 보내기 → 표식 읽기
    enum Action: Equatable {
        case started
        case skipTapped
        case laterTapped
        case stepCompleted(step: Int)   // 연결 28
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {

            case .started:
                // step 시작 값은 미정
                return .none

            case .skipTapped:
                // 건너뛰기 동작은 미정
                return .none

            case .laterTapped:
                // 나중에 동작은 미정
                return .none

            case .stepCompleted:
                // 단계 이동과 tutorialDone을 쓰는 시점은 미정
                return .none
            }
        }
    }
}
