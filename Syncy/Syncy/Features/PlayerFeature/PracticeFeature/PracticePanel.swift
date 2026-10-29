//
//  PracticePanel.swift
//  Syncy
//
//  Created by anna on 10/22/26.
//

import SwiftUI
import ComposableArchitecture

enum PracticePopover: Equatable {
    case metronome
    case speed
}

struct PracticePanel: View {
    let store: StoreOf<PracticeFeature>
    @Binding var presentedPopover: PracticePopover?

    var body: some View {
        HStack(spacing: 12) {
            MetronomeSettingsButton(
                isEnabled: store.isMetronomeEnabled,
                bpm: store.displayedMetronomeBPM,
                volume: store.metronomeVolume,
                isPresented: presentation(for: .metronome),
                onEnabledChanged: { store.send($0 ? .metronomeOnTapped : .metronomeOffTapped) },
                onBPMChanged: { store.send(.metronomeBPMChanged($0)) },
                onVolumeChanged: { store.send(.metronomeVolumeChanged($0)) }
            )

            PlaybackSpeedButton(rate: store.tempo, isPresented: presentation(for: .speed)) {
                store.send(.tempoChanged($0))
            }
        }
        .fixedSize()
    }

    private func presentation(for popover: PracticePopover) -> Binding<Bool> {
        Binding(
            get: { presentedPopover == popover },
            set: { isPresented in
                if isPresented {
                    presentedPopover = popover
                } else if presentedPopover == popover {
                    presentedPopover = nil
                }
            }
        )
    }
}
