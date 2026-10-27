//
//  HomeFeature.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var shows: IdentifiedArrayOf<Show> = []
        var selectedShowID: UUID?
        var todos: [TodoItem] = []
        var isEditing = false
        @Presents var destination: Destination?
        // 곡 추가할 때 세션별 담당자 후보를 여기서 읽음 (후보 = 멤버 중 part가 같은 사람)
        @Shared(.currentBand) var currentBand: Band?
    }

    // 안에 담는 값은 미정
    enum Destination: Equatable {
        case showForm
        case songForm
        case moveSong
        case allFeedback
    }

    @Dependency(\.showClient) var showClient
    @Dependency(\.feedbackQueryClient) var feedbackQueryClient

    enum Action: Equatable {
        case task
        case showsLoaded   // 인자 미정
        case showSelected   // 인자 미정
        case showFormSubmitted(ShowDraft)
        case songFormSubmitted(SongDraft)   // 세션별 담당자 선택을 같이 보냄 (10/27)
        case setlistMoved   // 인자 미정
        case songDeleted   // 인자 미정
        case songMovedToShow   // 인자 미정
        case songTapped(songID: String)
        case songStepRequested   // 인자 direction 타입 미정
        case songStatusChanged(songID: String, status: SongStatus)

        case delegate(Delegate)
        enum Delegate: Equatable {
            case songOpened(SongRef)
            case songAddRequested(SongDraft)
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {

            case .task:
                // ShowClient.shows, FeedbackQueryClient.todos 호출은 미정
                return .none

            case .showsLoaded:
                // shows에 담는 방법은 미정
                return .none

            case .showSelected:
                // selectedShowID에 담는 방법은 미정
                return .none

            case .showFormSubmitted:
                // ShowClient.createShow 호출은 미정
                return .none

            // 연결 18
            case let .songFormSubmitted(draft):
                return .send(.delegate(.songAddRequested(draft)))

            case .setlistMoved:
                // ShowClient.reorder 호출은 미정
                return .none

            case .songDeleted:
                // ShowClient.deleteSong 호출은 미정
                return .none

            case .songMovedToShow:
                // ShowClient.moveSong 호출은 미정
                return .none

            case .songTapped:
                // songOpened(SongRef)를 보내는 방법은 미정 (연결 17)
                return .none

            case .songStepRequested:
                // 이웃 곡을 찾는 방법은 미정 (연결 23, 찾으면 17번과 같은 길)
                return .none

            case .songStatusChanged:
                // 곡 상태를 반영하는 방법은 미정 (연결 19)
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
