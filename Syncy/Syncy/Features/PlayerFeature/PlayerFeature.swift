//
//  PlayerFeature.swift
//  Syncy
//
//  Created by anna on 10/22/26.
//

import SwiftUI
import Combine
import ComposableArchitecture

@Reducer
struct PlayerFeature {
    @ObservableState
    struct State: Equatable {
        var songID: String?
        var practice = PracticeFeature.State()
        var tracks: IdentifiedArrayOf<TrackState> = []
        var waveforms: [SessionID: WaveformPeaks] = [:]
        var waveformErrors: [SessionID: String] = [:]
        var loadPhase: LoadPhase = .idle
        var isPlaying: Bool = false
        var playbackRate: Float = 1.0
        var loopRange: ClosedRange<TimeInterval>?
        var soloTrackID: SessionID?
        var recordingPhase: RecordingPhase = .idle
        var recordingTarget: RecordingTarget?
        @Shared(.pinDraft) var pinDraft: PinDraft?
        @Shared(.activePin) var activePin: ActivePin?
        @Shared(.patches) var patches: IdentifiedArrayOf<Patch>
        @Presents var destination: Destination.State?
        var beatGrid: BeatGrid? = nil
        var duration: TimeInterval = 0
        var isChangingPlayback: Bool = false
    }
    
    nonisolated private enum CancelID: Hashable, Sendable {
        case load
        case playback
        case events
        case countIn
        case recording
        case controls
        case patches
        case waveforms
    }
    
    @Dependency(\.audioClient) var audioClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.waveformClient) var waveformClient
    
    enum Action: Sendable {
        case practice(PracticeFeature.Action)
        case task
        case playPauseTapped
        case seekChanged(time: TimeInterval)
        case volumeChanged(trackID: SessionID, volume: Float)
        case muteTapped(trackID: SessionID)
        case soloTapped(trackID: SessionID)
        case pinDraftStarted(trackID: SessionID)
        case startPointSetTapped(time: TimeInterval)
        case endPointSetTapped(time: TimeInterval)
        case patchSelected(patch: Patch)
        case originalSelected(trackID: SessionID, range: ClosedRange<TimeInterval>)
        case songLoaded(Song)
        case loadResponse(duration: TimeInterval)
        case loadFailureResponse(reason: String)
        case waveformResponse(songID: String, trackID: SessionID, peaks: WaveformPeaks)
        case waveformFailureResponse(songID: String, trackID: SessionID, reason: String)
        case patchesChanged
        case recordTapped
        case recordCancelTapped
        case audioEvent(AudioEvent)
        case recordingPermissionResponse
        case countInTicked
        case countInFinished
        case recordingRangeEnded
        case recordingResponse(fileURL: URL)
        case recordingFailureResponse(reason: String)
        case recordingStartedResponse
        case recordingCancelledResponse
        
        case destination(PresentationAction<Destination.Action>)
        enum Alert: Equatable, Sendable {
            
        }
        
        case delegate(Delegate)
        enum Delegate: Sendable {
            case recordingFinished(target: RecordingTarget, fileURL: URL)
        }
        
        case playbackResponse(isPlaying: Bool)
        case playbackFailureResponse(reason: String)
    }
    
    var body: some Reducer<State, Action> {
        Scope(state: \.practice, action: \.practice) {
            PracticeFeature()
        }

        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    .run { [audioClient] send in
                        for await event in await audioClient.events() {
                            try Task.checkCancellation()
                            await send(.audioEvent(event))
                        }
                    }
                        .cancellable(id: CancelID.events, cancelInFlight: true),
                    .run { [patches = state.$patches] send in
                        for await _ in patches.publisher.values {
                            try Task.checkCancellation()
                            await send(.patchesChanged)
                        }
                    }
                        .cancellable(id: CancelID.patches, cancelInFlight: true)
                )
                
            case let .songLoaded(song):
                state.songID = song.id
                state.waveforms = [:]
                state.waveformErrors = [:]
                state.loadPhase = .loading
                state.isPlaying = false
                state.playbackRate = 1.0
                state.loopRange = nil
                state.soloTrackID = nil
                state.recordingPhase = .idle
                state.recordingTarget = nil
                state.destination = nil
                state.isChangingPlayback = false
                state.duration = 0
                
                state.tracks = IdentifiedArray(
                    uniqueElements: song.tracks.map { track in
                        TrackState(
                            id: track.id,
                            volume: 1.0,
                            isMuted: false,
                            activePatchIDs: []
                        )
                    }
                )
                
                let beatGrid = BeatGrid(
                    bpm: song.bpm,
                    firstBeatOffset: song.firstBeatOffset
                )
                state.beatGrid = beatGrid
                
                let loadEffect: Effect<Action> = .run {
                    [audioClient, tracks = song.tracks, beatGrid] send in
                    do {
                        await audioClient.cancelRecording()
                        try Task.checkCancellation()
                        await audioClient.pause()
                        try Task.checkCancellation()
                        
                        let duration = try await audioClient.load(tracks, beatGrid)
                        try Task.checkCancellation()
                        
                        await send(.loadResponse(duration: duration))
                    } catch is CancellationError {
                        return
                    } catch {
                        guard !Task.isCancelled else { return }
                        
                        await send(
                            .loadFailureResponse(
                                reason: error.localizedDescription
                            )
                        )
                    }
                }
                    .cancellable(id: CancelID.load, cancelInFlight: true)

                let waveformEffect: Effect<Action> = .run {
                    [waveformClient, songID = song.id, tracks = song.tracks] send in
                    for track in tracks {
                        do {
                            let peaks = try await waveformClient.peaks(track.fileURL, 8_192)
                            try Task.checkCancellation()
                            await send(.waveformResponse(songID: songID, trackID: track.id, peaks: peaks))
                        } catch is CancellationError {
                            return
                        } catch {
                            guard !Task.isCancelled else { return }
                            await send(.waveformFailureResponse(
                                songID: songID, trackID: track.id, reason: error.localizedDescription
                            ))
                        }
                    }
                }
                .cancellable(id: CancelID.waveforms, cancelInFlight: true)

                return .concatenate(
                    .cancel(id: CancelID.playback),
                    .cancel(id: CancelID.controls),
                    .cancel(id: CancelID.countIn),
                    .cancel(id: CancelID.recording),
                    .send(.practice(.songOpened(bpm: song.bpm))),
                    .merge(loadEffect, waveformEffect)
                )

            case let .waveformResponse(songID, trackID, peaks):
                guard state.songID == songID, state.tracks[id: trackID] != nil else { return .none }
                state.waveforms[trackID] = peaks
                state.waveformErrors[trackID] = nil
                return .none

            case let .waveformFailureResponse(songID, trackID, reason):
                guard state.songID == songID, state.tracks[id: trackID] != nil else { return .none }
                state.waveformErrors[trackID] = reason
                return .none
                
            case let .loadResponse(duration):
                guard state.loadPhase == .loading else { return .none }
                guard duration.isFinite, duration > 0 else {
                    return .send(.loadFailureResponse(reason: "곡 길이를 확인할 수 없어요."))
                }
                state.duration = duration
                state.loadPhase = .ready
                return .send(.patchesChanged)
                
            case let .loadFailureResponse(reason):
                guard state.loadPhase == .loading else { return .none }
                state.loadPhase = .failed(reason: reason)
                
                state.destination = Self.alert("곡을 불러오지 못했어요.", reason: reason)
                return .none
                
            case .playPauseTapped:
                guard state.loadPhase == .ready,
                      state.recordingPhase == .idle,
                      !state.isChangingPlayback else {
                    return .none
                }
                
                let shouldPlay = !state.isPlaying
                state.isChangingPlayback = true
                
                return .run { [audioClient] send in
                    do {
                        if shouldPlay {
                            try await audioClient.play()
                        } else {
                            await audioClient.pause()
                        }
                        
                        try Task.checkCancellation()
                        
                        await send(.playbackResponse(isPlaying: shouldPlay))
                    } catch is CancellationError {
                        return
                    } catch {
                        guard !Task.isCancelled else { return }
                        
                        await send(
                            .playbackFailureResponse(
                                reason: error.localizedDescription
                            )
                        )
                    }
                }
                .cancellable(id: CancelID.playback)
                
            case let .playbackResponse(isPlaying):
                guard state.loadPhase == .ready,
                      state.isChangingPlayback else {
                    return .none
                }
                
                state.isChangingPlayback = false
                state.isPlaying = isPlaying
                return .none
                
            case let .playbackFailureResponse(reason):
                guard state.loadPhase == .ready,
                      state.isChangingPlayback else {
                    return .none
                }
                
                state.isChangingPlayback = false
                state.isPlaying = false
                
                state.destination = Self.alert("재생을 시작하지 못했어요.", reason: reason)
                return .none
                
            case let .seekChanged(time):
                guard state.loadPhase == .ready,
                      state.recordingPhase == .idle,
                      time.isFinite,
                      time >= 0, time <= state.duration else {
                    return .none
                }
                
                return .run { [audioClient] _ in
                    await audioClient.seek(time)
                }
                .cancellable(id: CancelID.controls)
                
            case let .volumeChanged(trackID, volume):
                guard state.loadPhase == .ready,
                      state.recordingPhase == .idle,
                      volume.isFinite,
                      var track = state.tracks[id: trackID] else {
                    return .none
                }
                
                let newVolume = min(max(volume, 0), 1)
                
                track.volume = newVolume
                state.tracks[id: trackID] = track
                
                return .run { [audioClient] _ in
                    await audioClient.setVolume(trackID, newVolume)
                }
                .cancellable(id: CancelID.controls)
                
            case let .muteTapped(trackID):
                guard state.loadPhase == .ready,
                      state.recordingPhase == .idle,
                      var track = state.tracks[id: trackID] else {
                    return .none
                }
                
                track.isMuted.toggle()
                state.tracks[id: trackID] = track
                
                let isMuted = track.isMuted
                
                return .run { [audioClient] _ in
                    await audioClient.setMuted(trackID, isMuted)
                }
                .cancellable(id: CancelID.controls)
                
            case let .soloTapped(trackID):
                guard state.loadPhase == .ready,
                      state.recordingPhase == .idle,
                      state.tracks[id: trackID] != nil else {
                    return .none
                }
                
                let soloTrackID: SessionID? =
                state.soloTrackID == trackID ? nil : trackID
                
                state.soloTrackID = soloTrackID
                
                return .run { [audioClient] _ in
                    await audioClient.setSolo(soloTrackID)
                }
                .cancellable(id: CancelID.controls)
                
            case let .pinDraftStarted(trackID):
                guard state.loadPhase == .ready,
                      state.recordingPhase == .idle,
                      state.tracks[id: trackID] != nil else {
                    return .none
                }
                
                state.$pinDraft.withLock { draft in
                    draft = PinDraft(
                        sessionID: trackID,
                        startTime: nil,
                        endTime: nil
                    )
                }
                return .none
                
            case let .startPointSetTapped(time):
                guard state.loadPhase == .ready,
                      time.isFinite,
                      time >= 0, time <= state.duration else {
                    return .none
                }
                
                state.$pinDraft.withLock { draft in
                    draft?.startTime = time
                }
                return .none
                
            case let .endPointSetTapped(time):
                guard state.loadPhase == .ready,
                      time.isFinite,
                      time >= 0, time <= state.duration else {
                    return .none
                }
                
                state.$pinDraft.withLock { draft in
                    draft?.endTime = time
                }
                return .none
                
            case .recordTapped:
                guard state.loadPhase == .ready,
                      state.recordingPhase == .idle,
                      !state.isChangingPlayback,
                      let pin = state.activePin,
                      state.tracks[id: pin.sessionID] != nil,
                      let beatGrid = state.beatGrid,
                      beatGrid.bpm > 0,
                      pin.range.lowerBound.isFinite,
                      pin.range.upperBound.isFinite,
                      pin.range.lowerBound >= 0,
                      pin.range.upperBound <= state.duration,
                      pin.range.lowerBound < pin.range.upperBound else {
                    return .none
                }
                
                state.recordingTarget = RecordingTarget(
                    pinID: pin.pinID, range: pin.range, sessionID: pin.sessionID
                )
                state.recordingPhase = .requestingPermission
                state.isPlaying = false
                
                return .concatenate(
                    .cancel(id: CancelID.playback),
                    .cancel(id: CancelID.controls),
                    .run { [audioClient, clock, bpm = beatGrid.bpm] send in
                        do {
                            await audioClient.pause()
                            try Task.checkCancellation()
                            try await audioClient.requestRecordingPermission()
                            try Task.checkCancellation()
                            await send(.recordingPermissionResponse)
                            try Task.checkCancellation()
                            for beat in 1...4 {
                                await audioClient.click(beat == 1)
                                try Task.checkCancellation()
                                await send(.countInTicked)
                                try await clock.sleep(for: .seconds(60 / Double(bpm)))
                            }
                            await send(.countInFinished)
                        } catch is CancellationError {
                            return
                        } catch {
                            guard !Task.isCancelled else { return }
                            await send(.recordingFailureResponse(reason: error.localizedDescription))
                        }
                    }
                        .cancellable(id: CancelID.countIn, cancelInFlight: true)
                )
                
            case .recordingPermissionResponse:
                guard state.recordingPhase == .requestingPermission,
                      state.recordingTarget != nil else { return .none }
                state.recordingPhase = .countIn(beat: 0)
                return .none

            case .countInTicked:
                guard case let .countIn(beat) = state.recordingPhase,
                      beat < 4 else { return .none }
                state.recordingPhase = .countIn(beat: beat + 1)
                return .none
                
            case .countInFinished:
                guard state.recordingPhase == .countIn(beat: 4),
                      let target = state.recordingTarget else { return .none }
                
                return .run { [audioClient] send in
                    do {
                        try await audioClient.startRecording(target.sessionID, target.range)
                        try Task.checkCancellation()
                        let positions = await audioClient.position()
                        try Task.checkCancellation()
                        await send(.recordingStartedResponse)
                        for await position in positions {
                            try Task.checkCancellation()
                            if position >= target.range.upperBound {
                                await send(.recordingRangeEnded)
                                return
                            }
                        }
                        try Task.checkCancellation()
                        await send(.recordingFailureResponse(reason: "녹음 중 재생 위치 수신이 중단됐어요."))
                    } catch is CancellationError {
                        return
                    } catch {
                        guard !Task.isCancelled else { return }
                        await send(.recordingFailureResponse(reason: error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.recording, cancelInFlight: true)
                
            case .recordingStartedResponse:
                guard case .countIn = state.recordingPhase,
                      state.recordingTarget != nil else { return .none }
                state.recordingPhase = .recording
                state.isPlaying = true
                return .none
                
            case .recordingRangeEnded:
                guard state.recordingPhase == .recording else { return .none }
                state.recordingPhase = .finishing
                state.isPlaying = false
                return .run { [audioClient] send in
                    do {
                        let fileURL = try await audioClient.stopRecording()
                        try Task.checkCancellation()
                        await send(.recordingResponse(fileURL: fileURL))
                    } catch is CancellationError {
                        return
                    } catch {
                        guard !Task.isCancelled else { return }
                        await send(.recordingFailureResponse(reason: error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.recording, cancelInFlight: true)
                
            case let .recordingResponse(fileURL):
                guard state.recordingPhase == .finishing,
                      let target = state.recordingTarget else { return .none }
                state.recordingPhase = .idle
                state.recordingTarget = nil
                return .send(.delegate(.recordingFinished(target: target, fileURL: fileURL)))
                
            case .recordCancelTapped:
                guard state.recordingPhase != .idle else { return .none }
                return cancelRecording(state: &state)
                
            case let .recordingFailureResponse(reason):
                guard state.recordingPhase != .idle else { return .none }
                state.destination = Self.alert("녹음을 완료하지 못했어요.", reason: reason)
                return cancelRecording(state: &state)
                
            case .recordingCancelledResponse:
                guard state.recordingPhase == .finishing else { return .none }
                state.recordingPhase = .idle
                state.recordingTarget = nil
                return .none
                
            case .audioEvent(.playbackEnded):
                state.isPlaying = false
                state.isChangingPlayback = false
                if state.recordingPhase == .recording {
                    return .send(.recordingRangeEnded)
                }
                return .cancel(id: CancelID.playback)
                
            case .audioEvent(.interrupted):
                state.isPlaying = false
                state.isChangingPlayback = false
                if state.recordingPhase != .idle {
                    state.destination = Self.alert("오디오가 중단되어 녹음을 취소했어요.")
                    return cancelRecording(state: &state)
                }
                return .concatenate(
                    .cancel(id: CancelID.playback),
                    .run { [audioClient] _ in await audioClient.pause() }
                        .cancellable(id: CancelID.controls)
                )
                
            case let .audioEvent(.recordingFailed(reason)):
                guard state.recordingPhase != .idle else { return .none }
                return .send(.recordingFailureResponse(reason: reason))
                
            case .audioEvent(.loopWrapped):
                // Practice의 반복 횟수·단계 처리 Action이 정해지면 전달한다.
                return .none
                
            case .patchSelected:
                // shortcut: 패치 파일 URL 전달 방식이 정해지면 activatePatch에 연결한다.
                return .none
                
            case let .originalSelected(trackID, range):
                guard state.loadPhase == .ready,
                      state.recordingPhase == .idle,
                      var track = state.tracks[id: trackID] else { return .none }
                let patchIDs = track.activePatchIDs.filter { id in
                    guard let patch = state.patches[id: id] else { return true }
                    return patch.startTime < range.upperBound && range.lowerBound < patch.endTime
                }
                track.activePatchIDs.subtract(patchIDs)
                state.tracks[id: trackID] = track
                return .run { [audioClient] _ in
                    for id in patchIDs {
                        try Task.checkCancellation()
                        await audioClient.deactivatePatch(id, trackID)
                    }
                }
                .cancellable(id: CancelID.controls)
                
            case .patchesChanged:
                guard state.loadPhase == .ready else { return .none }
                // 활성화는 파일 URL 연결 후 구현한다. 삭제·등록 해제된 패치는 끈다.
                let patches = state.patches
                var removed: [(UUID, SessionID)] = []
                for index in state.tracks.indices {
                    let trackID = state.tracks[index].id
                    let ids = state.tracks[index].activePatchIDs.filter {
                        patches[id: $0]?.isAdopted != true
                    }
                    state.tracks[index].activePatchIDs.subtract(ids)
                    removed += ids.map { ($0, trackID) }
                }
                return .run { [audioClient, removed] _ in
                    for (id, trackID) in removed {
                        try Task.checkCancellation()
                        await audioClient.deactivatePatch(id, trackID)
                    }
                }
                .cancellable(id: CancelID.controls)
                
            case let .practice(.delegate(.playback(command))):
                guard state.loadPhase == .ready,
                      state.recordingPhase == .idle else {
                    state.practice.tempo = state.playbackRate
                    state.practice.isLoopEnabled = state.loopRange != nil
                    return .none
                }

                switch command {
                case let .rate(rate):
                    guard rate.isFinite, rate > 0 else {
                        state.practice.tempo = state.playbackRate
                        return .none
                    }
                    let rate = min(max(rate, 1.0 / 32), 32)
                    state.playbackRate = rate
                    state.practice.tempo = rate
                    return .run { [audioClient] _ in
                        try Task.checkCancellation()
                        await audioClient.setRate(rate)
                    }
                    .cancellable(id: CancelID.controls)

                case let .loop(range):
                    if let range {
                        guard range.lowerBound.isFinite, range.upperBound.isFinite,
                              range.lowerBound >= 0, range.upperBound <= state.duration,
                              range.lowerBound < range.upperBound else {
                            state.practice.isLoopEnabled = state.loopRange != nil
                            return .none
                        }
                    }
                    state.loopRange = range
                    return .run { [audioClient] _ in
                        try Task.checkCancellation()
                        await audioClient.setLoop(range)
                    }
                    .cancellable(id: CancelID.controls)

                case .stop:
                    state.isPlaying = false
                    state.isChangingPlayback = false
                    return .concatenate(
                        .cancel(id: CancelID.playback),
                        .run { [audioClient] _ in await audioClient.pause() }
                            .cancellable(id: CancelID.controls)
                    )
                }

            case .practice(.delegate(.recordRequested)):
                return .send(.recordTapped)

            case .practice, .destination, .delegate:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
    
    private static func alert(_ title: String, reason: String? = nil) -> Destination.State {
        .alert(AlertState(
            title: { TextState(title) },
            actions: { ButtonState(role: .cancel) { TextState("확인") } },
            message: reason.map { reason in { TextState(reason) } }
        ))
    }
    
    private func cancelRecording(state: inout State) -> Effect<Action> {
        guard state.recordingTarget != nil else { return .none }
        state.isPlaying = false
        state.isChangingPlayback = false
        state.recordingPhase = .finishing
        state.recordingTarget = nil
        return .concatenate(
            .cancel(id: CancelID.countIn),
            .cancel(id: CancelID.recording),
            .cancel(id: CancelID.playback),
            .run { [audioClient] send in
                await audioClient.cancelRecording()
                try Task.checkCancellation()
                await audioClient.pause()
                try Task.checkCancellation()
                await send(.recordingCancelledResponse)
            }
                .cancellable(id: CancelID.recording)
        )
    }
}
