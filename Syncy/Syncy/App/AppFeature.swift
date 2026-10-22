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
        var session: SessionFeature.State = SessionFeature.State()
    }
    
    @Dependency(\.profileClient) var profileClient
    
    enum Action: Equatable {
      case task
      case session(SessionFeature.Action)
    }
   
    var body: some Reducer<State, Action> {
        Scope(state: \.session, action: \.session) {
            SessionFeature()
        }

        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    // 비동기 로직 구현
                }
            case let .session(.delegate(.songReady(song))):
                print("AppFeature: 곡 준비 완료 -> \(song.id)")
                return .none

            case .session:
                return .none
            }
        }
    }


}
