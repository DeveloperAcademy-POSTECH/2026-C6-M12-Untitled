//
//  OnboardingFeature.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct OnboardingFeature {
    @ObservableState
    struct State: Equatable {
        var step: OnboardingStep = .intro(1)   // 시작 단계는 미정
        // profileDraft는 타입 미정
        var inviteCode: String = ""
        var foundBand: Band?
        var bandDraft: BandDraft = BandDraft()
        var lineup: [Part] = []
        // myPart는 타입 미정
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.profileClient) var profileClient
    @Dependency(\.bandClient) var bandClient

    enum Action: Equatable {
        case signInTapped   // 인자 method 타입 미정
        case signInResponse   // 인자 미정
        case profileSubmitted
        case inviteCodeChanged(code: String)
        case bandLookupResponse   // 인자 미정
        case joinConfirmed
        case bandCreateSubmitted
        case partSelected   // 인자 미정
        case partAdded(name: String)
        case inviteShareTapped

        case delegate(Delegate)
        enum Delegate: Equatable {
            case finished(me: Person, band: Band)
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {

            case .signInTapped:
                // AuthClient 호출은 미정
                return .none

            case .signInResponse:
                // 단계 이동은 미정
                return .none

            case .profileSubmitted:
                // ProfileClient.update 호출과 단계 이동은 미정
                return .none

            case .inviteCodeChanged:
                // BandClient.find 호출은 미정 (끝나면 bandLookupResponse)
                return .none

            case .bandLookupResponse:
                // foundBand에 담는 방법은 미정
                return .none

            case .joinConfirmed:
                // BandClient.join 호출과 단계 이동은 미정
                return .none

            case .bandCreateSubmitted:
                // BandClient.create 호출과 단계 이동은 미정
                return .none

            case .partSelected:
                // myPart에 담는 방법은 미정
                return .none

            case .partAdded:
                // lineup에 넣는 방법과 BandClient.addPart 호출은 미정
                return .none

            case .inviteShareTapped:
                // 공유 방법은 미정
                return .none

            case .delegate:
                // finished를 보내는 시점은 미정
                return .none
            }
        }
    }
}
