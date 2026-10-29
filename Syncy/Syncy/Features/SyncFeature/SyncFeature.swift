//
//  SyncFeature.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct SyncFeature {

    @ObservableState
    struct State: Equatable {
        var status: SyncStatus = .idle
        var pendingTasks: [PendingSyncTask] = []
        var lastAppliedServerVersion: Int?
        var lastSongJobID: String?
        
        var isSending = false
    }

    @Dependency(\.syncClient) var syncClient
    @Dependency(\.continuousClock) var clock

    nonisolated private enum CancelID: Hashable, Sendable {
        case poll
        case pull
    }

    enum Action: Equatable {
        case task
        case pollTicked
        case syncRequested
        case taskEnqueued(PendingSyncTask)
        case pendingTaskSucceeded
        case pendingTaskFailed(reason: String)
        case remoteDataReceived(RemoteState)
        case remoteDataFailed(reason: String)
        case remoteDataApplied(version: Int)
        case retryTapped

        case delegate(Delegate)
        enum Delegate: Equatable {
            case remoteStateReady(RemoteState)
            case sharedSongChanged(jobID: String, bpm: Int, firstBeatOffset: TimeInterval)
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            // 정해진 간격마다 pollTicked를 보낸다. 오래 도는 Effect라 cancellable을 붙인다.
            case .task:
                return .run { send in
                    for await _ in clock.timer(interval: ServerConfig.syncPollInterval) {
                        await send(.pollTicked)
                    }
                }
                .cancellable(id: CancelID.poll, cancelInFlight: true)

            // 받기: 서버 버전이 같으면 nil, 바뀌었으면 RemoteState.
            case .pollTicked:
                return .run { [since = state.lastAppliedServerVersion] send in
                    do {
                        if let remote = try await syncClient.pull(since) {
                            await send(.remoteDataReceived(remote))
                        } else {
                            // 바뀐 게 없다. 서버가 비어 있어 since가 없으면 0으로 본다.
                            await send(.remoteDataApplied(version: since ?? 0))
                        }
                    } catch {
                        await send(.remoteDataFailed(reason: error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.pull, cancelInFlight: true)

            // 받은 데이터를 부모에게 알린다. 공유 곡이 바뀌었으면 그 알림이 먼저 간다.
            case let .remoteDataReceived(remote):
                var effects: [Effect<Action>] = []
                if let jobID = remote.songJobId,
                   let bpm = remote.songBPM,
                   let firstBeatOffset = remote.firstBeatOffset,
                   jobID != state.lastSongJobID {
                    state.lastSongJobID = jobID
                    effects.append(.send(.delegate(.sharedSongChanged(
                        jobID: jobID, bpm: bpm, firstBeatOffset: firstBeatOffset
                    ))))
                }
                effects.append(.send(.delegate(.remoteStateReady(remote))))
                return .concatenate(effects)

            case let .remoteDataFailed(reason):
                state.status = .failed(reason: reason)
                return .none

            // 부모가 서버 데이터를 반영했다고 알려 준다. 연결이 돌아왔으면 못 보낸 일도 이어서 보낸다.
            case let .remoteDataApplied(version):
                state.lastAppliedServerVersion = version
                if state.pendingTasks.isEmpty {
                    if !state.isSending { state.status = .synced }
                    return .none
                }
                return .send(.syncRequested)

            // 보내기: 대기열의 맨 앞 일을 하나씩 순서대로 보낸다.
            case let .taskEnqueued(task):
                state.pendingTasks.append(task)
                return .send(.syncRequested)

            case .syncRequested:
                guard !state.isSending, let task = state.pendingTasks.first else { return .none }
                state.isSending = true
                state.status = .syncing
                return .run { send in
                    do {
                        switch task {
                        case let .operation(op):
                            try await syncClient.send([op])
                        case let .audioUpload(patchID, fileURL):
                            try await syncClient.uploadAudio(patchID, fileURL)
                        }
                        await send(.pendingTaskSucceeded)
                    } catch {
                        await send(.pendingTaskFailed(reason: error.localizedDescription))
                    }
                }

            case .pendingTaskSucceeded:
                state.isSending = false
                state.pendingTasks.removeFirst()
                if state.pendingTasks.isEmpty {
                    state.status = .synced
                    return .none
                }
                return .send(.syncRequested)

            // 실패하면 대기열에 그대로 남긴다. 오프라인이어도 일이 사라지지 않는다.
            case let .pendingTaskFailed(reason):
                state.isSending = false
                state.status = .failed(reason: reason)
                return .none

            case .retryTapped:
                return .merge(.send(.syncRequested), .send(.pollTicked))

            case .delegate:
                return .none
            }
        }
    }
}
