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
        // @Shared 키는 SharedKeys 구현되면 확정
        @Shared var pinDraft: PinDraft?
        @Shared var activePin: ActivePin?
        @Shared var patches: IdentifiedArrayOf<Patch>
        var appliedServerVersion: Int?  // 서버 것을 받았는지
        // @Presents var alertt: AlertState? -> 액션/타입 미정이라 일단 이렇게
    }
    
    @Dependency(\.storageClient) var storageClient
    
    enum Action: Equatable {
        case songOpened(songID: String)
        case pinsLoaded(songID: String, pins: [FeedbackItem], patches: [Patch])
        case meChanged(Person)
        case createPinTapped(text: String)
        case pinDraftCancelled
        case pinDeleted                // 작성자만, 인자 미정
        case pinOpened(id: FeedbackItem.ID)
        case pinClosed
        case commentPosted             // 인자 미정
        case commentDeleted            // 인자 미정
        case recordingFinished(target: RecordingTarget, fileURL: URL)
        case recordingSavedSuccessResponse(target: RecordingTarget, fileURL: URL, patch: Patch)
        case recordingSavedFailureResponse(reason: String)
        case patchRegistered(patchID: UUID)
        case patchUnregistered         // 인자 미정
        case patchDeleted              // 인자 미정
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
                // 불러오기 실패 처리는 아직 미정
                return .run { send in
                    let pins = try await storageClient.loadFeedback(songID)
                    let patches = try await storageClient.loadPatches(songID)
                    await send(.pinsLoaded(songID: songID, pins: pins, patches: patches))
                }
                
            case let .pinsLoaded(songID, pins, patches):
                // songID가 다르거나 서버 것을 이미 받았으면 버림
                guard state.songID == songID, state.appliedServerVersion == nil else { return .none }
                state.pins = IdentifiedArray(uniqueElements: pins)
                state.$patches.withLock { $0 = IdentifiedArray(uniqueElements: patches) }
                return .none
                
            case let .meChanged(person):
                state.me = person
                return .none
                
            case let .createPinTapped(text):
                guard let draft = state.pinDraft, let songID = state.songID else { return .none }
                // canConfirm 조건은 의미 미정, PinDraft 구현되면 확정
                let item = FeedbackItem(
                    id: UUID(),
                    startTime: draft.startTime,
                    endTime: draft.endTime,
                    createdAt: Date(),
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
                    // .feedbackAdded 연관값 미정
                    .send(.delegate(.opProduced(.feedbackAdded)))
                )
                
            case .pinDraftCancelled:
                state.$pinDraft.withLock { $0 = nil }
                return .none
                
            case .pinDeleted:
                // 어떤 핀인지 미정
                // canDelete(by: me) 확인 -> saveFeedback -> opProduced(.feedbackDeleted)
                return .none
                
            case let .pinOpened(id):
                guard let pin = state.pins[id: id] else { return .none }
                state.$activePin.withLock {
                    $0 = ActivePin(pinID: id, range: pin.timeRange, sessionIDs: pin.targetSessionIds)
                }
                return .send(.delegate(.pinOpened(pin)))
                
            case .pinClosed:
                state.$activePin.withLock { $0 = nil }
                return .none
                
            case .commentPosted, .commentDeleted:
                // 핀에 다는지 녹음 답에 다는지 미정
                return .none
                
            case let .recordingFinished(target, fileURL):
                guard let songID = state.songID else { return .none }
                return .run { send in
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let patchID = UUID()
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
                    id: UUID(),
                    author: state.me,
                    sessionId: target.sessionID,
                    patchId: patch.id,
                    createdAt: Date(),
                    comments: []
                )
                state.pins[id: target.pinID]?.attempts.append(attempt)
                return .merge(
                    .run { [patches = Array(state.patches)] _ in
                        try await storageClient.savePatches(songID, patches)
                    },
                    // 연관값 미정
                    .send(.delegate(.opProduced(.attemptAdded))),
                    .send(.delegate(.opProduced(.patchUpserted))),
                    .send(.delegate(.audioSaved(patchID: patch.id, fileURL: fileURL)))
                )
                
            case .recordingSavedFailureResponse:
                // 실패 처리 미정 (alert 등?)
                return .none
                
            case let .patchRegistered(patchID):
                // 받은 파트만 등록 가능 - 판정 방법 미정
                guard let songID = state.songID else { return .none }
                state.$patches.withLock { $0[id: patchID]?.isAdopted = true }
                return .merge(
                    .run { [patches = Array(state.patches)] _ in
                        try await storageClient.savePatches(songID, patches)
                    },
                    .send(.delegate(.opProduced(.patchUpserted)))   // 연관값 미정
                )
                
            case .patchUnregistered, .patchDeleted:
                // 어떤 패치인지 인자 미정
                return .none
                
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
