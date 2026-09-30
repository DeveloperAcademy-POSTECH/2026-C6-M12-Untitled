import SwiftUI
import ScoreDetectCore

/// Bottom audio bar: import button when no audio is loaded; otherwise play/pause,
/// scrubber, a "now playing" measure label, and a collapsible BPM/beats/offset editor
/// that drives AudioSyncSettings' automatic per-measure timing.
struct AudioSyncPanel: View {
    @ObservedObject var player: AudioPlayerManager
    @Binding var syncSettings: AudioSyncSettings
    let onImportTapped: () -> Void
    let currentMeasureLabel: String?

    private static let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if player.hasAudio {
                HStack(spacing: 14) {
                    Button(action: player.togglePlayPause) {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 34))
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 2) {
                        Slider(
                            value: Binding(
                                get: { player.currentTime },
                                set: { player.seek(to: $0) }
                            ),
                            in: 0...max(player.duration, 0.01)
                        )
                        HStack {
                            Text(Self.timeFormatter.string(from: player.currentTime) ?? "0:00")
                            Spacer()
                            if let currentMeasureLabel {
                                Text(currentMeasureLabel)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                            }
                            Spacer()
                            Text(Self.timeFormatter.string(from: player.duration) ?? "0:00")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Button("오디오 변경", action: onImportTapped)
                        .font(.footnote)
                }

                DisclosureGroup(
                    "박자 설정 · BPM \(Int(syncSettings.bpm)) · 오프셋 \(String(format: "%.1f", syncSettings.startOffsetSeconds))초"
                ) {
                    syncFields
                }
                .font(.footnote)
            } else {
                Button(action: onImportTapped) {
                    Label("원곡 오디오 불러오기", systemImage: "waveform.badge.plus")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if let loadErrorMessage = player.loadErrorMessage {
                    Text(loadErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
    }

    private var syncFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            syncStepper(title: "BPM", value: $syncSettings.bpm, range: 20...300, step: 1)
            syncStepper(title: "박자 (마디당 박수)", value: $syncSettings.beatsPerMeasure, range: 1...12, step: 1)
            syncStepper(title: "시작 오프셋 (초)", value: $syncSettings.startOffsetSeconds, range: 0...60, step: 0.5)
            Text("마디마다 직접 태그하지 않고 이 세 값으로 전체 마디의 재생 시점을 자동 계산해요. 템포가 일정한 곡에서 잘 맞아요.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func syncStepper(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(String(format: step < 1 ? "%.1f" : "%.0f", value.wrappedValue))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
        }
    }
}
