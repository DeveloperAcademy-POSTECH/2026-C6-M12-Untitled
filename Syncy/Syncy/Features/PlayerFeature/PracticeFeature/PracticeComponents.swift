//
//  PracticeComponents.swift
//  Syncy
//
//  Created by anna on 10/29/26.
//

import SwiftUI

struct PracticeIconButton: View {
    enum Kind {
        case loop
        case metronome
    }

    let kind: Kind
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isActive ? Color.black : Color("Gray100"))
                .frame(width: 57, height: 34)
                .background(isActive ? Color("Gray100") : Color("Surface3"))
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var symbolName: String {
        switch kind {
        case .loop: "repeat"
        case .metronome: "metronome.fill"
        }
    }
}

struct PlaybackSpeedButton: View {
    let rate: Float
    let onRateChanged: (Float) -> Void

    @State private var isPresented = false

    private let rates: [Float] = [0.8, 0.9, 1.0]

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Text("속도")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color("Gray300"))

                Text("\(Int((rate * 100).rounded()))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)

                Text("▾")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color("Gray300"))
            }
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .frame(height: 34)
            .background(Color("Surface3"), in: RoundedRectangle(cornerRadius: 8))
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if isPresented {
                // 버튼의 보이는 아래 끝(39pt)에서 8pt 띄운다.
                speedOptions.offset(y: 47)
            }
        }
        .zIndex(isPresented ? 1 : 0)
        .onDisappear { isPresented = false }
    }

    private var speedOptions: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("재생 속도")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color("Gray400"))
                .padding(.leading, 12)
                .padding(.top, 6)
                .padding(.bottom, 4)

            ForEach(rates, id: \.self) { option in
                Button {
                    onRateChanged(option)
                    isPresented = false
                } label: {
                    HStack {
                        Text("\(Int((option * 100).rounded()))%")
                            .font(.system(size: 15, weight: rate == option ? .bold : .medium))
                            .foregroundStyle(rate == option ? .white : Color("Gray200"))

                        Spacer()

                        if rate == option {
                            Text("✓")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color("AccentPrimary"))
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(
                        rate == option ? Color("AlphaWhite10") : .clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .frame(width: 156)
        .background(Color("Surface2"), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color("Surface4"), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.4), radius: 12, y: 10)
    }
}

struct MetronomeSettingsButton: View {
    let isEnabled: Bool
    let bpm: Double
    let volume: Int
    let onEnabledChanged: (Bool) -> Void
    let onBPMChanged: (Double) -> Void
    let onVolumeChanged: (Int) -> Void

    @State private var isPresented = false
    @State private var bpmText = ""
    @FocusState private var isBPMFocused: Bool

    private let bpmRange = 30.0...300.0

    var body: some View {
        PracticeIconButton(kind: .metronome, isActive: isEnabled) {
            if isPresented {
                commitBPM()
            } else {
                bpmText = bpmInput(bpm)
            }
            isBPMFocused = false
            isPresented.toggle()
        }
        .overlay(alignment: .topLeading) {
            if isPresented {
                settings.offset(y: 47)
            }
        }
        .zIndex(isPresented ? 1 : 0)
        .onChange(of: isBPMFocused) { _, isFocused in
            if !isFocused { commitBPM() }
        }
        .onChange(of: bpm) { _, value in
            if !isBPMFocused {
                bpmText = bpmInput(value)
            }
        }
        .onDisappear { isPresented = false }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {

            Toggle("메트로놈", isOn: Binding(
                get: { isEnabled },
                set: { onEnabledChanged($0) }
            ))
            .tint(Color("AccentPrimary"))

            HStack {
                Text("BPM")
                Spacer()

                HStack(spacing: 4) {
                    Button {
                        changeBPM(by: -1)
                    } label: {
                        Text("−")
                            .frame(width: 32, height: 32)
                            .background(Color("Surface3"), in: RoundedRectangle(cornerRadius: 6))
                    }

                    TextField("BPM", text: $bpmText)
                        .font(.system(size: 15, weight: .bold))
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .focused($isBPMFocused)
                        .frame(width: 48, height: 32)
                        .background(Color("Surface3"), in: RoundedRectangle(cornerRadius: 6))
                        .onSubmit { isBPMFocused = false }

                    Button {
                        changeBPM(by: 1)
                    } label: {
                        Text("+")
                            .frame(width: 32, height: 32)
                            .background(Color("Surface3"), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 6) {
                HStack {
                    Text("볼륨")
                    Spacer()
                    Text("\(volume)%")
                        .foregroundStyle(Color("Gray300"))
                }

                Slider(value: Binding(
                    get: { Double(volume) },
                    set: { onVolumeChanged(Int($0)) }
                ), in: 0...100, step: 1)
                .tint(Color("AccentPrimary"))
            }
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Color("Gray100"))
        .padding(12)
        .frame(width: 244)
        .background(Color("Surface2"), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color("Surface4"), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.4), radius: 12, y: 10)
    }

    private func commitBPM() {
        guard let value = Double(bpmText), value.isFinite else {
            bpmText = bpmInput(bpm)
            return
        }
        guard value != bpm else {
            bpmText = bpmInput(bpm)
            return
        }
        updateBPM(value)
    }

    private func changeBPM(by amount: Double) {
        let value = Double(bpmText).flatMap { $0.isFinite ? $0 : nil } ?? bpm
        updateBPM(value + amount)
        isBPMFocused = false
    }

    private func updateBPM(_ value: Double) {
        let value = min(max(value, bpmRange.lowerBound), bpmRange.upperBound)
        bpmText = bpmInput(value)
        if value != bpm { onBPMChanged(value) }
    }

    private func bpmInput(_ value: Double) -> String {
        let text = String(value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }
}
