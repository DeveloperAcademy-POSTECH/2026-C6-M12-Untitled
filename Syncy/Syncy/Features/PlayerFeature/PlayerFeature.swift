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
        var beatGrid: BeatGrid? = nil
    }
    
    // @Dependency(\.audioClient) var audioClient
}
