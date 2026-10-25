//
//  FeedbackFeature.swift
//  Syncy
//
//  Created by moo on 10/22/26.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct FeedbackFeature {
    @ObservableState
    struct State: Equatable {
        var me: Person
        var songID: String?
        var pins: IdentifiedArrayOf<FeedbackItem> = []
        @Shared(.pinDraft) var pinDraft: PinDraft?
        @Shared(.activePin) var activePin: ActivePin?
        @Shared(.patches) var patches: IdentifiedArrayOf<Patch>
        var appliedServerVersion: Int?  // 서버 것을 받았는지
        // @Presents var alertt: AlertState? -> 액션/타입 미정이라 일단 이렇게
    }
    
    @Dependency(\.storageClient) var storageClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date
    
    enum Action: Equatable {
        case songOpened(songID: String)
        case pinsLoaded(songID: String, pins: [FeedbackItem], patches: [Patch])
        case pinsLoadFailureResponse(reason: String)
        case meChanged(Person)
        case createPinTapped(text: String)
        case pinDraftCancelled
        case pinDeleted(id: FeedbackItem.ID)   // 작성자만
        case pinOpened(id: FeedbackItem.ID)
        case pinClosed
        case commentPosted(feedbackID: UUID, attemptID: UUID?, text: String)   // attemptID 없으면 핀, 있으면 그 녹음 답
        case commentDeleted(commentID: UUID, feedbackID: UUID, attemptID: UUID?)   // 작성자만
        case recordingFinished(target: RecordingTarget, fileURL: URL)
        case recordingSavedSuccessResponse(target: RecordingTarget, fileURL: URL, patch: Patch)
        case recordingSavedFailureResponse(reason: String)
        case patchRegistered(patchID: UUID)
        case patchUnregistered(patchID: UUID)
        case patchDeleted(patchID: UUID)   // 지울 수 있는 사람 미정
        case remoteReplaced(feedback: [FeedbackItem], patches: [Patch], version: Int)   // RemoteState 구현되면 타입 확정

        case delegate(Delegate)
        enum Delegate: Equatable{
            case opProduced(SyncOp)
            case audioSaved(patchID: UUID, fileURL: URL)
            case pinOpened(FeedbackItem)
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let.songOpened(songID):
                state.songID = songID
                state.pins = []
                state.appliedServerVersion = nil
                state.$pinDraft.withLock { $0 = nil }
                state.$activePin.withLock { $0 = nil }
                return .run { send in
                    do {
                        let pins = try await storageClient.loadFeedback(songID)
                        let patches = try await storageClient.loadPatches(songID)
                        await send(.pinsLoaded(songID: songID, pins: pins, patches: patches))
                    } catch {
                        await send(.pinsLoadFailureResponse(reason: error.localizedDescription))
                    }
                }
                
            case let .pinsLoaded(songID, pins, patches):
                // songID가 다르거나 서버 것을 이미 받았으면 버림
                guard state.songID == songID, state.appliedServerVersion == nil else { return .none }
                state.pins = IdentifiedArray(uniqueElements: pins)
                state.$patches.withLock { $0 = IdentifiedArray(uniqueElements: patches) }
                return .none
                
            case .pinsLoadFailureResponse:
                // 실패 처리 미정 (alert 등?)
                return .none

            case let .meChanged(person):
                state.me = person
                return .none
                
            case let .createPinTapped(text):
                guard let draft = state.pinDraft, draft.canConfirm, let range = draft.range,
                      let songID = state.songID else { return .none }
                let item = FeedbackItem(
                    id: uuid(),
                    startTime: range.lowerBound,
                    endTime: range.upperBound,
                    createdAt: date.now,
                    text: text,
                    author: state.me,
                    translations: nil,
                    targetSessionIds: [draft.sessionID],
                    attempts: [],
                    comments: []
                )
                state.pins.append(item)
                state.$pinDraft.withLock { $0 = nil }
                return .merge(
                    .run { [pins = Array(state.pins)] _ in
                        try await storageClient.saveFeedback(songID, pins)
                    },
                    .send(.delegate(.opProduced(.feedbackAdded(item))))
                )
                
            case .pinDraftCancelled:
                state.$pinDraft.withLock { $0 = nil }
                return .none
                
            case let .pinDeleted(id):
                guard let songID = state.songID,
                      let pin = state.pins[id: id],
                      pin.canDelete(by: state.me) else { return .none }
                state.pins.remove(id: id)
                if state.activePin?.pinID == id {
                    state.$activePin.withLock { $0 = nil }
                }
                // 지운 핀에 달린 패치를 어떻게 할지 미정
                return .merge(
                    .run { [pins = Array(state.pins)] _ in
                        try await storageClient.saveFeedback(songID, pins)
                    },
                    .send(.delegate(.opProduced(.feedbackDeleted(id: id))))
                )
                
            case let .pinOpened(id):
                guard let pin = state.pins[id: id] else { return .none }
                state.$activePin.withLock {
                    $0 = ActivePin(pinID: id, range: pin.timeRange, sessionIDs: pin.targetSessionIds)
                }
                return .send(.delegate(.pinOpened(pin)))
                
            case .pinClosed:
                state.$activePin.withLock { $0 = nil }
                return .none
                
            case let .commentPosted(feedbackID, attemptID, text):
                guard let songID = state.songID, state.pins[id: feedbackID] != nil else { return .none }
                let comment = FeedbackComment(
                    id: uuid(),
                    author: state.me,
                    text: text,
                    createdAt: date.now,
                    translations: nil   // 번역은 아직 미정
                )
                if let attemptID {
                    guard let index = state.pins[id: feedbackID]?.attempts.firstIndex(where: { $0.id == attemptID }) else { return .none }
                    state.pins[id: feedbackID]?.attempts[index].comments.append(comment)
                } else {
                    state.pins[id: feedbackID]?.comments.append(comment)
                }
                return .merge(
                    .run { [pins = Array(state.pins)] _ in
                        try await storageClient.saveFeedback(songID, pins)
                    },
                    .send(.delegate(.opProduced(.commentAdded(comment, feedbackID: feedbackID, attemptID: attemptID))))
                )

            case let .commentDeleted(commentID, feedbackID, attemptID):
                guard let songID = state.songID, state.pins[id: feedbackID] != nil else { return .none }
                if let attemptID {
                    guard let index = state.pins[id: feedbackID]?.attempts.firstIndex(where: { $0.id == attemptID }),
                          let comment = state.pins[id: feedbackID]?.attempts[index].comments.first(where: { $0.id == commentID }),
                          comment.author.id == state.me.id else { return .none }
                    state.pins[id: feedbackID]?.attempts[index].comments.removeAll { $0.id == commentID }
                } else {
                    guard let comment = state.pins[id: feedbackID]?.comments.first(where: { $0.id == commentID }),
                          comment.author.id == state.me.id else { return .none }
                    state.pins[id: feedbackID]?.comments.removeAll { $0.id == commentID }
                }
                return .merge(
                    .run { [pins = Array(state.pins)] _ in
                        try await storageClient.saveFeedback(songID, pins)
                    },
                    .send(.delegate(.opProduced(.commentDeleted(id: commentID, feedbackID: feedbackID, attemptID: attemptID))))
                )
                
            case let .recordingFinished(target, fileURL):
                guard let songID = state.songID else { return .none }
                return .run { send in
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let patchID = uuid()
                        _ = try await storageClient.savePatchFile(data, patchID, songID)
                        // Patch를 어떻게 만드는지 구현되면 작성. 위에서 받은 URL 사용
                        // let patch = Patch(~~)
                        // await send(.recordingSavedSuccessResponse(target: target, fileURL: fileURL, patch: patch))
                    } catch {
                        await send(.recordingSavedFailureResponse(reason: "녹음 저장 실패"))
                    }
                }
                
            case let .recordingSavedSuccessResponse(target, fileURL, patch):
                guard let songID = state.songID else { return .none }
                state.$patches.withLock { $0.append(patch) }
                let attempt = FeedbackAttempt(
                    id: uuid(),
                    author: state.me,
                    sessionId: target.sessionID,
                    patchId: patch.id,
                    createdAt: date.now,
                    comments: []
                )
                state.pins[id: target.pinID]?.attempts.append(attempt)
                return .merge(
                    .run { [patches = Array(state.patches)] _ in
                        try await storageClient.savePatches(songID, patches)
                    },
                    .send(.delegate(.opProduced(.attemptAdded(attempt, feedbackID: target.pinID)))),
                    .send(.delegate(.opProduced(.patchUpserted(patch)))),
                    .send(.delegate(.audioSaved(patchID: patch.id, fileURL: fileURL)))
                )
                
            case .recordingSavedFailureResponse:
                // 실패 처리 미정 (alert 등?)
                return .none
                
            case let .patchRegistered(patchID):
                // 받은 파트만 등록 가능 - 판정 방법 미정
                guard let songID = state.songID else { return .none }
                state.$patches.withLock { $0[id: patchID]?.isAdopted = true }
                guard let patch = state.patches[id: patchID] else { return .none }
                return .merge(
                    .run { [patches = Array(state.patches)] _ in
                        try await storageClient.savePatches(songID, patches)
                    },
                    .send(.delegate(.opProduced(.patchUpserted(patch))))
                )
                
            case let .patchUnregistered(patchID):
                guard let songID = state.songID else { return .none }
                state.$patches.withLock { $0[id: patchID]?.isAdopted = false }
                guard let patch = state.patches[id: patchID] else { return .none }
                return .merge(
                    .run { [patches = Array(state.patches)] _ in
                        try await storageClient.savePatches(songID, patches)
                    },
                    .send(.delegate(.opProduced(.patchUpserted(patch))))
                )

            case let .patchDeleted(patchID):
                // 누가 지울 수 있는지 미정
                guard let songID = state.songID, state.patches[id: patchID] != nil else { return .none }
                state.$patches.withLock { $0.remove(id: patchID) }
                // 저장된 녹음 파일 삭제는 StorageClient에 함수가 없어 미정
                return .merge(
                    .run { [patches = Array(state.patches)] _ in
                        try await storageClient.savePatches(songID, patches)
                    },
                    .send(.delegate(.opProduced(.patchDeleted(id: patchID))))
                )
                
            case let .remoteReplaced(feedback, patches, version):
                state.pins = IdentifiedArray(uniqueElements: feedback)
                state.$patches.withLock { $0 = IdentifiedArray(uniqueElements: patches) }
                state.appliedServerVersion = version
                // 열린 핀이 없어졌으면 activePin = nil
                if let pinID = state.activePin?.pinID, state.pins[id: pinID] == nil {
                    state.$activePin.withLock { $0 = nil }
                }
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}
