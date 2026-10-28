//
//  PracticeFeature.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct PracticeFeature {
    @ObservableState
    struct State: Equatable {
        var selectedFeedbackID: UUID?
        var practiceRange: ClosedRange<TimeInterval>?
        var isLoopEnabled: Bool = false
        var tempo: Float = 1.0
        var stage: PracticeStage = .idle       // 미정: 단계가 바뀌는 시점
        var candidates: [FeedbackItem] = []    // 미정: 후보를 채우는 시점
        var isMetronomeEnabled: Bool = false   // 미정: 기본값
        var metronomeVolume: Int = 100         // 미정: 기본값 (0~100)
        var metronomeBPM: Double = 120         // 미정: 기본값 (0보다 큼). 곡이 열리면 곡 BPM으로 바뀜
    }
    
    nonisolated private enum CancelID: Hashable, Sendable {
        case metronome
    }
    
    @Dependency(\.audioClient) var audioClient
    
    enum Action: Sendable {
        case songOpened(bpm: Double)
        case feedbackSelected(feedbackID: UUID, range: ClosedRange<TimeInterval>)
        case practiceRangeChanged(range: ClosedRange<TimeInterval>)
        case loopTapped(duration: TimeInterval, selectedRange: ClosedRange<TimeInterval>?)
        case loopOnTapped
        case loopOffTapped
        case tempoChanged(Float)
        case metronomeOnTapped
        case metronomeOffTapped
        case metronomeVolumeChanged(Int)
        case metronomeBPMChanged(Double)
        case practiceRequested(FeedbackItem)
        case practiceStartTapped
        case candidateSelected(id: FeedbackItem.ID)
        case onceMoreTapped
        case recordTapped
        
        case delegate(Delegate)
        enum Delegate: Sendable {
            case playback(PracticeCommand)
            case recordRequested
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .songOpened(bpm):
                state.metronomeBPM = bpm
                state.selectedFeedbackID = nil
                state.practiceRange = nil
                state.isLoopEnabled = false
                state.tempo = 1.0
                state.stage = .idle
                state.candidates = []
                // 메트로놈이 켜져 있던 경우 처리는 미정
                return .none
                
            case let .feedbackSelected(feedbackID, range):
                // 구간 반복은 준비만 한다. 켜는 건 loopOnTapped
                state.selectedFeedbackID = feedbackID
                state.practiceRange = range
                return .none
                
            case let .practiceRangeChanged(range):
                state.practiceRange = range
                // 반복이 켜진 중에 구간이 바뀌면 다시 보낼지 미정
                return .none
                
            case let .loopTapped(duration, selectedRange):
                if state.isLoopEnabled {
                    return .send(.loopOffTapped)
                }
                guard duration.isFinite, duration > 0 else { return .none }
                let range = selectedRange ?? 0...duration
                guard range.lowerBound.isFinite, range.upperBound.isFinite,
                      range.lowerBound >= 0, range.upperBound <= duration,
                      range.lowerBound < range.upperBound else { return .none }

                state.practiceRange = range
                return .send(.loopOnTapped)

            case .loopOnTapped:
                guard let range = state.practiceRange else { return .none }
                state.isLoopEnabled = true
                return .send(.delegate(.playback(.loop(range))))
                
            case .loopOffTapped:
                state.isLoopEnabled = false
                return .send(.delegate(.playback(.loop(nil))))
                
            case let .tempoChanged(tempo):
                state.tempo = tempo
                return .send(.delegate(.playback(.rate(tempo))))
                
            case .metronomeOnTapped:
                state.isMetronomeEnabled = true
                return setMetronome(state: state)
                
            case .metronomeOffTapped:
                state.isMetronomeEnabled = false
                return setMetronome(state: state)
                
            case let .metronomeVolumeChanged(volume):
                // 0~100 범위를 벗어난 값 처리는 미정
                state.metronomeVolume = volume
                return setMetronome(state: state)
                
            case let .metronomeBPMChanged(bpm):
                // 0 이하 값 처리는 미정
                state.metronomeBPM = bpm
                return setMetronome(state: state)
                
            case .practiceRequested:
                // 미정: Feedback이 보낸 핀으로 연습을 준비하는 동작 (구간 · 후보 · 단계)
                return .none
                
            case .practiceStartTapped:
                // 미정: 연습을 시작할 때의 단계 변화 (countIn → looping)
                return .none
                
            case .candidateSelected:
                // 미정: 후보를 골랐을 때의 동작
                return .none
                
            case .onceMoreTapped:
                // 미정: 한 번 더 연습할 때의 단계 변화
                return .none
                
            case .recordTapped:
                // 녹음은 Player가 한다. 부모에게 알리기만 한다 (연결 25)
                // 미정: stage를 .recording으로 바꾸는 시점
                return .send(.delegate(.recordRequested))
                
            case .delegate:
                return .none
            }
        }
    }
    
    // 메트로놈은 Player를 거치지 않고 AudioClient를 직접 부른다.
    private func setMetronome(state: State) -> Effect<Action> {
        .run { [audioClient, on = state.isMetronomeEnabled, bpm = state.metronomeBPM, volume = Float(state.metronomeVolume)] _ in
            await audioClient.setMetronome(on, bpm, volume)
        }
        .cancellable(id: CancelID.metronome, cancelInFlight: true)
    }
}
