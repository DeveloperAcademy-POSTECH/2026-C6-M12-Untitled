//
//  NotificationFeature.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct NotificationFeature {
    @ObservableState
    struct State: Equatable {
        var items: IdentifiedArrayOf<AppNotification> = []
        // filter는 타입 미정
        var unreadCount: Int = 0   // 세는 시점은 미정
        var banner: AppNotification?
    }

    @Dependency(\.notificationClient) var notificationClient

    nonisolated private enum CancelID: Hashable, Sendable {
        case stream
    }

    enum Action: Equatable {
        case task   // 구독
        case received(AppNotification)
        case filterChanged   // 인자 미정
        case markAllReadTapped
        case itemTapped(id: AppNotification.ID)
        case permissionRequested

        case delegate(Delegate)
        enum Delegate: Equatable {
            case openRequested(songID: String, pinID: UUID?)
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            // 연결 27
            case .task:
                return .run { send in
                    for await notification in await notificationClient.stream() {
                        await send(.received(notification))
                    }
                }
                .cancellable(id: CancelID.stream, cancelInFlight: true)

            case .received:
                // items · banner · unreadCount에 반영하는 방법은 미정
                return .none

            case .filterChanged:
                // filter 변경과 NotificationClient.list 호출은 미정
                return .none

            case .markAllReadTapped:
                // NotificationClient.markAllRead 호출은 미정
                return .none

            // 연결 20
            case let .itemTapped(id):
                // songID가 없는 알림은 미정
                guard let item = state.items[id: id], let songID = item.songID else { return .none }
                return .send(.delegate(.openRequested(songID: songID, pinID: item.pinID)))

            case .permissionRequested:
                // NotificationClient.requestAuthorization, registerDeviceToken 호출은 미정
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
