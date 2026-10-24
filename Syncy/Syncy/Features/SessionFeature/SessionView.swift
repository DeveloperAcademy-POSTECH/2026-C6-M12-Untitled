//
//  SessionView.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import SwiftUI
import UniformTypeIdentifiers
import ComposableArchitecture

struct SessionView: View {
    let store: StoreOf<SessionFeature>

    @State private var isImporterPresented = false
    @State private var bpmText = "120"
    @State private var firstBeatText = "0"

    var body: some View {
        VStack(spacing: 24) {
            Text("곡 분리")
                .font(.title.bold())

            fileSection
            songInfoSection
            statusSection
        }
        .padding(32)
        .frame(maxWidth: 560)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.audio]
        ) { result in
            if case let .success(fileURL) = result {
                store.send(.fileSelected(fileURL: fileURL))
            }
        }
    }

    // MARK: - 곡 고르기

    private var fileSection: some View {
        VStack(spacing: 8) {
            Button("곡 선택하기") {
                isImporterPresented = true
            }
            .disabled(isBusy)

            Text(store.selectedFileURL?.lastPathComponent ?? "선택한 곡이 없습니다")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - BPM · 첫 박 입력

    private var songInfoSection: some View {
        HStack(spacing: 16) {
            LabeledContent("BPM") {
                TextField("120", text: $bpmText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent("첫 박 위치(초)") {
                TextField("0", text: $firstBeatText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .disabled(isBusy)
        .onChange(of: bpmText) { sendSongInfo() }
        .onChange(of: firstBeatText) { sendSongInfo() }
    }

    private func sendSongInfo() {
        // 숫자가 아니면 보내지 않는다 (직전 값을 유지)
        guard let bpm = Double(bpmText), bpm > 0,
              let firstBeat = Double(firstBeatText), firstBeat >= 0 else { return }
        store.send(.songInfoEntered(bpm: bpm, firstBeat: firstBeat))
    }

    // MARK: - phase별 상태

    @ViewBuilder
    private var statusSection: some View {
        switch store.phase {
        case .idle:
            startButton(title: "분리 시작")

        case .uploading:
            progress("곡을 올리는 중…")

        case .separating:
            progress("파트별로 나누는 중… (곡에 따라 몇 분 걸려요)")

        case .downloading:
            progress("나뉜 파트를 받는 중…")

        case .ready:
            Label("준비 완료 (\(store.tracks.count)파트)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case let .uploadFailed(reason):
            failure(reason)
        case let .separationFailed(reason):
            failure(reason)
        case let .downloadFailed(reason):
            failure(reason)
        }
    }

    private func startButton(title: String) -> some View {
        Button(title) {
            store.send(.startSeparationTapped)
        }
        .buttonStyle(.borderedProminent)
        .disabled(store.selectedFileURL == nil)
    }

    private func progress(_ message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func failure(_ reason: String) -> some View {
        VStack(spacing: 12) {
            Label(reason, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            startButton(title: "다시 시도")
        }
    }

    /// 올리고 · 나누고 · 받는 동안에는 곡과 입력을 바꾸지 못하게 한다.
    private var isBusy: Bool {
        switch store.phase {
        case .uploading, .separating, .downloading: return true
        default: return false
        }
    }
}
