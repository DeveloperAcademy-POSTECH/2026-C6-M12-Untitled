//
//  PlayerView.swift
//  Syncy
//
//  Created by anna on 10/22/26.
//

import SwiftUI
import ComposableArchitecture

struct PlayerView: View {
    @Bindable var store: StoreOf<PlayerFeature>
    let beatGrid: BeatGrid
    // TODO: 파트별 멤버 데이터가 연결되면 TrackHeaderView에 필수 이름을 전달한다.

    var body: some View {
        VStack(spacing: 0) {
            topBar
            trackArea
        }
        .foregroundStyle(Color("Gray100"))
        .background(Color("Surface1"))
        .task {
            await store.send(.task).finish()
        }
        .alert($store.scope(\.$destination, action: \.destination).alert) { action in
            guard let action else { return }
            store.send(.destination(.presented(.alert(action))))
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 1) {
                Button {
                    // 뒤로가기 버튼 Action
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .regular))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                // songTitle 연결 필요
                Text("songTitle")
                    .font(.system(size: 22, weight: .light))
                    .tracking(1.76)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                playbackControls
                PlayerPlaybackPositionView(beatGrid: beatGrid)

            }
            .fixedSize()

            Spacer(minLength: 0)
                .frame(maxWidth: .infinity)
        }
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Color("Surface2"))
    }

    private var playbackControls: some View {
        HStack(spacing: 2) {
            PlayerIconButton(kind: .restart) {
                store.send(.seekChanged(time: 0))
            }

            PlayerIconButton(kind: .play, isActive: store.isPlaying) {
                store.send(.playPauseTapped)
            }

            PlayerIconButton(kind: .record, isActive: store.recordingPhase != .idle) {
                switch store.recordingPhase {
                case .idle:
                    store.send(.recordTapped)
                case .requestingPermission, .countIn, .recording:
                    store.send(.recordCancelTapped)
                case .finishing:
                    break
                }
            }

            PlayerIconButton(kind: .loop, isActive: store.loopRange != nil) {
                store.send(.loopTapped)
            }
        }
    }

    private var trackArea: some View {
        GeometryReader { geometry in
            let timelineWidth = max(1, geometry.size.width - PlayerLayout.headerWidth)
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    trackHeaders
                        .frame(minHeight: geometry.size.height, alignment: .top)

                    PlayerTimelineView(
                        tracks: displayedTracks,
                        waveforms: store.waveforms,
                        waveformErrors: store.waveformErrors,
                        beatGrid: beatGrid,
                        duration: store.duration,
                        viewportWidth: timelineWidth,
                        isSeekingAllowed: store.recordingPhase == .idle,
                        onSeek: { store.send(.seekChanged(time: $0)) }
                    )
                    .frame(width: timelineWidth)
                    .zIndex(1)
                }
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color("Surface2"))
    }

    private var trackHeaders: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: PlayerLayout.rulerHeight)
            ForEach(displayedTracks) { track in
                TrackHeaderView(
                    trackName: track.id.playerTitle,
                    isMuted: track.isMuted,
                    isSolo: store.soloTrackID == track.id,
                    volume: Binding(
                        get: { store.tracks[id: track.id]?.volume ?? 0 },
                        set: { store.send(.volumeChanged(trackID: track.id, volume: $0)) }
                    ),
                    onMuteTapped: { store.send(.muteTapped(trackID: track.id)) },
                    onSoloTapped: { store.send(.soloTapped(trackID: track.id)) }
                )
            }
        }
        .frame(width: PlayerLayout.headerWidth)
        .background(Color("Surface1"))
    }

    private var displayedTracks: [TrackState] {
        store.tracks.sorted { $0.id.playerOrder < $1.id.playerOrder }
    }
}

private struct PlayerPlaybackPositionView: View {
    let beatGrid: BeatGrid

    @Dependency(\.audioClient) private var audioClient
    @State private var time: TimeInterval = 0

    var body: some View {
        PlaybackPositionView(position: position)
            .task {
                for await time in await audioClient.position() {
                    guard !Task.isCancelled else { return }
                    guard time.isFinite, time >= 0 else { continue }
                    self.time = time
                }
            }
    }

    private var position: MusicalPosition {
        beatGrid.position(at: time)
    }
}

#Preview("가로 모드", traits: .landscapeLeft) {
    PlayerPreview.makeView()
}

#if DEBUG
private enum PlayerPreview {
    static func makeView() -> some View {
        let order: [SessionID] = [.vocals, .piano, .guitar, .drums, .bass]
        var state = PlayerFeature.State()
        state.loadPhase = .ready
        state.duration = 20
        let beatGrid = BeatGrid(bpm: 120, firstBeatOffset: 0)
        state.beatGrid = beatGrid
        state.tracks = IdentifiedArray(uniqueElements: order.map {
            TrackState(id: $0, volume: 0.8, isMuted: false, activePatchIDs: [])
        })
        for (index, id) in order.enumerated() {
            // 파형 예시는 Preview에서만 만들며, 실제 화면은 WaveformClient의 결과를 쓴다.
            let samples = (0..<1_600).map { sample -> Float in
                let phase = Double(sample) / 1_600
                let pulse = abs(sin(phase * .pi * Double(index == 0 ? 5 : 20)))
                let detail = 0.4 + 0.6 * abs(sin(Double(sample) * Double(index + 3)))
                return Float(max(0.02, pulse * detail))
            }
            state.waveforms[id] = WaveformPeaks(samples: samples, duration: 20)
        }
        return withDependencies {
            var audioClient = AudioClient()
            audioClient.play = {}
            audioClient.pause = {}
            audioClient.seek = { _ in }
            audioClient.setVolume = { _, _ in }
            audioClient.setMuted = { _, _ in }
            audioClient.setSolo = { _ in }
            audioClient.setLoop = { _ in }
            audioClient.events = { AsyncStream { $0.finish() } }
            audioClient.position = { AsyncStream { $0.yield(0); $0.finish() } }
            $0.audioClient = audioClient
        } operation: {
            PlayerView(store: Store(initialState: state) { PlayerFeature() }, beatGrid: beatGrid)
        }
    }
}
#endif
