//
//  PlayerFeature.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct PlayerFeature {
    @ObservableState
    struct State: Equatable {
        var tracks: IdentifiedArrayOf<TrackState> = []
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
    }
    
    // @Dependency(\.audioClient) var audioClient
    
    enum Action: Sendable {
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
        case patchesChanged
        case recordTapped(SessionID?)
        case recordCancelTapped
        case audioEvent(AudioEvent)
        case countInTicked
        case countInFinished
        case recordingRangeEnded
        case recordingResponse(fileURL: URL)
        case recordingFailureResponse(reason: String)
        
        case destination(PresentationAction<Destination.Action>)
        enum Alert: Equatable, Sendable {
            
        }
        
        case delegate(Delegate)
        enum Delegate: Sendable {
            case recordingFinished(target: RecordingTarget, fileURL: URL)
        }
    }
}
