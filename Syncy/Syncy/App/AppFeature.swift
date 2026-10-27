//
//  AppFeature.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import ComposableArchitecture

@Reducer
struct AppFeature{
    @ObservableState
    struct State: Equatable{
        // me: Person은 로그인 전 값이 미정이라 아직 넣지 않음
        var route: AppRoute = .launching
        @Shared(.currentBand) var currentBand: Band?
        var session: SessionFeature.State = SessionFeature.State()
        var onboarding: OnboardingFeature.State = OnboardingFeature.State()
        var home: HomeFeature.State = HomeFeature.State()
        var notification: NotificationFeature.State = NotificationFeature.State()
        var settings: SettingsFeature.State = SettingsFeature.State()
        var tutorial: TutorialFeature.State = TutorialFeature.State()
    }
    
    @Dependency(\.profileClient) var profileClient
    @Dependency(\.authClient) var authClient
    
    enum Action: Equatable {
      case task
      case session(SessionFeature.Action)
      case onboarding(OnboardingFeature.Action)
      case home(HomeFeature.Action)
      case notification(NotificationFeature.Action)
      case settings(SettingsFeature.Action)
      case tutorial(TutorialFeature.Action)
    }
   
    var body: some Reducer<State, Action> {
        Scope(state: \.session, action: \.session) {
            SessionFeature()
        }
        Scope(state: \.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Scope(state: \.notification, action: \.notification) {
            NotificationFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Scope(state: \.tutorial, action: \.tutorial) {
            TutorialFeature()
        }

        Reduce { state, action in
            switch action {
            // 연결 15
            case .task:
                // AuthClient.currentUser로 route를 정하는 방법은 미정
                return .none

            case let .session(.delegate(.songReady(song))):
                print("AppFeature: 곡 준비 완료 -> \(song.id)")
                return .none

            // 연결 16: 온보딩이 끝났다.
            case let .onboarding(.delegate(.finished(_, band))):
                // me를 설정하는 방법은 미정
                state.$currentBand.withLock { $0 = band }
                state.route = .main(.home)
                return .none

            // 연결 17: 홈에서 곡을 열었다.
            case .home(.delegate(.songOpened)):
                // Session.openSongRequested 전달, route 변경, 튜토리얼 확인은 미정 (SessionFeature에 아직 없음)
                return .none

            // 연결 18: 홈에서 곡 추가를 요청했다.
            case .home(.delegate(.songAddRequested)):
                // Session.addSongRequested 전달은 미정 (SessionFeature에 아직 없음)
                return .none

            // 연결 20: 알림에서 곡 · 핀 열기를 요청했다.
            case .notification(.delegate(.openRequested)):
                // 17번과 같은 길 + Feedback.pinOpenRequested 전달은 미정
                return .none

            // 연결 21: 설정에서 내 정보가 바뀌었다.
            case .settings(.delegate(.meChanged)):
                // Feedback.meChanged 전달은 미정 (14번과 같은 길)
                return .none

            // 연결 22: 로그아웃 · 탈퇴하면 모든 상태를 지우고 온보딩으로 돌아간다.
            case .settings(.delegate(.signedOut)), .settings(.delegate(.accountDeleted)):
                state = State()
                state.$currentBand.withLock { $0 = nil }
                state.route = .onboarding
                return .none

            case .session, .onboarding, .home, .notification, .settings, .tutorial:
                return .none
            }
        }
    }
}
