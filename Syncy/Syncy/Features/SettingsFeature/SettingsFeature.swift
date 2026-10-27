//
//  SettingsFeature.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        // category는 타입 미정
        @Shared(.practiceSettings) var practiceSettings: PracticeSettings
        var notificationPrefs: NotificationPrefs = NotificationPrefs()
        var cacheSize: Int = 0   // 단위는 미정
        @Presents var destination: Destination?
    }

    // 탈퇴 확인 · 재인증. 안에 담는 값은 미정
    enum Destination: Equatable {
        case deleteConfirmation
        case reauthentication
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.profileClient) var profileClient
    @Dependency(\.bandClient) var bandClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.songCacheClient) var songCacheClient
    // AudioClient 입력 장치 (inputs · setInput)는 AudioClient에 아직 없어 미정

    enum Action: Equatable {
        case profileEdited   // 인자 미정
        case partChanged   // 인자 미정
        case leaveBandTapped
        case prefsChanged   // 인자 미정
        case practiceSettingChanged   // 인자 미정
        case clearCacheTapped
        case signOutTapped
        case deleteAccountConfirmed
        case reauthResponse   // 인자 미정

        case delegate(Delegate)
        enum Delegate: Equatable {
            case meChanged(Person)
            case signedOut
            case accountDeleted
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {

            case .profileEdited:
                // ProfileClient.update 호출과 meChanged를 보내는 시점은 미정 (연결 21)
                return .none

            case .partChanged:
                // ProfileClient.setPart 호출, currentBand 수정, meChanged를 보내는 시점은 미정 (연결 21)
                return .none

            case .leaveBandTapped:
                // BandClient.leave 호출과 currentBand 수정은 미정
                return .none

            case .prefsChanged:
                // NotificationClient.setPreferences 호출은 미정
                return .none

            case .practiceSettingChanged:
                // practiceSettings를 쓰는 방법은 미정
                return .none

            case .clearCacheTapped:
                // SongCacheClient.removeAll 호출은 미정
                return .none

            case .signOutTapped:
                // AuthClient.signOut 호출과 signedOut을 보내는 시점은 미정 (연결 22)
                return .none

            case .deleteAccountConfirmed:
                // AuthClient.deleteAccount 호출과 accountDeleted를 보내는 시점은 미정 (연결 22)
                return .none

            case .reauthResponse:
                // AuthClient.reauthenticate 결과 처리는 미정
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
