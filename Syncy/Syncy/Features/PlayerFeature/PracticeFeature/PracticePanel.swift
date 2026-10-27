//
//  PracticePanel.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import SwiftUI
import ComposableArchitecture

// PlayerView 안 패널. PlayerView가 scope로 store를 넘긴다.
// 배치는 임시이고, 화면 디자인이 정해지면 바꾼다.
struct PracticePanel: View {
    let store: StoreOf<PracticeFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            rangeSection
            tempoSection
            metronomeSection
        }
        .padding(16)
    }

    // MARK: - 연습 구간 · 구간 반복

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let range = store.practiceRange {
                Text(String(format: "연습 구간 %.1f초 ~ %.1f초", range.lowerBound, range.upperBound))
            } else {
                Text("연습 구간 없음")
                    .foregroundStyle(.secondary)
            }
            Toggle("구간 반복", isOn: Binding(
                get: { store.isLoopEnabled },
                set: { store.send($0 ? .loopOnTapped : .loopOffTapped) }
            ))
            .disabled(store.practiceRange == nil)
        }
    }

    // MARK: - 연습 템포

    private var tempoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "연습 템포 %.0f%%", store.tempo * 100))
            // 미정: 템포 범위
            Slider(
                value: Binding(
                    get: { Double(store.tempo) },
                    set: { store.send(.tempoChanged(Float($0))) }
                ),
                in: 0.5...1.0
            )
        }
    }

    // MARK: - 메트로놈

    private var metronomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("메트로놈", isOn: Binding(
                get: { store.isMetronomeEnabled },
                set: { store.send($0 ? .metronomeOnTapped : .metronomeOffTapped) }
            ))
            // 미정: BPM 범위 (0보다 커야 한다)
            Stepper(
                "BPM \(Int(store.metronomeBPM))",
                value: Binding(
                    get: { store.metronomeBPM },
                    set: { store.send(.metronomeBPMChanged($0)) }
                ),
                in: 30...300,
                step: 1
            )
            Text("볼륨 \(store.metronomeVolume)")
            Slider(
                value: Binding(
                    get: { Double(store.metronomeVolume) },
                    set: { store.send(.metronomeVolumeChanged(Int($0))) }
                ),
                in: 0...100,
                step: 1
            )
        }
    }
}
