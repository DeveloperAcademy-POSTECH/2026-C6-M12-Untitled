//
//  SessionFeature.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct SessionFeature{
    
    @ObservableState
    struct State: Equatable{
        var phase: SessionPhase = .idle
        var selectedFileURL: URL?
        var separationJobID: String?
        var tracks: [SongTrack] = []
        var songBPM : Int = 120
        var firstBeatOffset: TimeInterval = 0
        var serverURL: URL? = ServerConfig.separationBaseURL
        var serverStatus: ServerStatus = .searching
        var sharedSongJobID: String?
        var cachedSongJobID: String?
    }
    
    @Dependency(\.separationClient) var separationClient
    @Dependency(\.songCacheClient) var songCacheClient
    @Dependency(\.continuousClock) var clock

    enum Action: Equatable{
        case fileSelected(fileURL: URL)
        case songInfoEntered(bpm: Int, firstBeat: TimeInterval)
        case startSeparationTapped
        case uploadSuccessResponse(jobID: String)
        case uploadFailureResponse(reason: String)
        case statusPolled(JobStatus)
        case separationSuccessResponse
        case separationFailureResponse(reason: String)
        case downloadSuccessResponse(tracks: [SongTrack])
        case downloadFailureResponse(reason: String)

        case delegate(Delegate)
        enum Delegate: Equatable{
            case songReady(Song)
            case serverChanged(URL)
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let . fileSelected(fileURL):
                state.selectedFileURL = fileURL
                state.phase = .idle
                return .none
                
            case let .songInfoEntered(bpm, firstBeat):
                state.songBPM = bpm
                state.firstBeatOffset = firstBeat
                return .none
                
            case .startSeparationTapped:
                guard let fileURL = state.selectedFileURL,let serverURL = state.serverURL else {
                    state.phase = .uploadFailed(reason: "file or server URL를 찾을 수 없습니다.")
                    return .none
                }
                state.phase = .uploading
                return .run { send in
                    do {
                        let jobID = try await separationClient.upload(fileURL, serverURL)
                        await send(.uploadSuccessResponse(jobID: jobID))
                    } catch {
                        await send(.uploadFailureResponse(reason: error.localizedDescription))
                    }
                }
                
            case let .uploadSuccessResponse(jobID):
                state.separationJobID = jobID
                state.phase = .separating
                guard let serverURL = state.serverURL else { return .none }
                return .run { send in
                    do {
                        let status = try await separationClient.status(jobID, serverURL)
                        await send(.statusPolled(status))
                    } catch {
                        await send(.separationFailureResponse(reason: error.localizedDescription))
                    }
                }
                
            case let .uploadFailureResponse(reason):
                state.phase = .uploadFailed(reason: reason)
                return .none
                
            case let .statusPolled(status):
                switch status.state{
                case .queued, .processing:
                    guard let jobID = state.separationJobID, let serverURL = state.serverURL else { return .none }
                    return .run { send in
                        do {
                            try await clock.sleep(for: ServerConfig.statusPollInterval)
                            let nextStatus = try await separationClient.status(jobID, serverURL)
                            await send(.statusPolled(nextStatus))
                        } catch {
                            await send(.separationFailureResponse(reason: error.localizedDescription))
                        }
                    }
                case .done:
                    return .send(.separationSuccessResponse)
                case .error:
                    return .send(.separationFailureResponse(reason: status.error ?? "음원 분리 실패"))
                }
                
            case .separationSuccessResponse:
                state.phase = .downloading
                guard let jobID = state.separationJobID, let serverURL = state.serverURL else { return .none }
                return .run { send in
                    do {
                        let stems: [SessionID] = [.vocals, .drums, .bass, .guitar, .piano]
                        var tracks: [SongTrack] = []
                        for stem in stems {
                            let tempFile = try await separationClient.downloadStem(jobID, stem, serverURL)
                            let fileURL = try await songCacheClient.store(tempFile, jobID, stem)
                            tracks.append(SongTrack(id: stem, fileURL: fileURL))
                        }
                        await send(.downloadSuccessResponse(tracks: tracks))
                    } catch {
                        await send(.downloadFailureResponse(reason: error.localizedDescription))
                    }
                }
                
            case let .separationFailureResponse(reason):
                state.phase = .separationFailed(reason: reason)
                return .none
                
            case let .downloadSuccessResponse(tracks):
                state.tracks = tracks
                state.phase = .ready
                let song = Song(
                    id: state.separationJobID ?? "song_id",
                    tracks: tracks,
                    bpm: state.songBPM,
                    firstBeatOffset: state.firstBeatOffset
                )
                return .send(.delegate(.songReady(song)))
                
            case let .downloadFailureResponse(reason):
                state.phase = .downloadFailed(reason: reason)
                return .none
            
            case .delegate:
                return .none
            }
        }
    }
}
