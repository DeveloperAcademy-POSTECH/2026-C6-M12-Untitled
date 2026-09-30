import SwiftUI
import ScoreDetectCore

/// Sliders for every DetectionParameters field. Dragging a slider only updates the
/// value shown — detection is re-run explicitly via the button, since re-running on
/// every drag tick would be wasteful for a full-page scan.
struct DetectionControlsView: View {
    @Binding var parameters: DetectionParameters
    var onReanalyze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $parameters.useAutoCalibration) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("자동 보정 사용")
                        .font(.caption)
                    Text("Otsu 임계값 + 오선 두께/간격 자동 추정")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $parameters.useSkewCorrection) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("기울기 자동 보정")
                        .font(.caption)
                    Text("스캔/사진 악보가 살짝 기울어져 있어도 보정 시도")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                labeledSlider(
                    title: "최대 보정 각도(°)" + (parameters.useSkewCorrection ? "" : " (기울기 보정 꺼짐)"),
                    value: $parameters.maxSkewCorrectionDegrees,
                    range: 0.0...10.0,
                    format: "%.1f"
                )
            }
            .disabled(!parameters.useSkewCorrection)
            .opacity(parameters.useSkewCorrection ? 1.0 : 0.4)

            labeledSlider(
                title: "렌더 배율",
                value: Binding(
                    get: { Double(parameters.renderScale) },
                    set: { parameters.renderScale = CGFloat($0) }
                ),
                range: 1.5...5.0,
                format: "%.1f"
            )

            VStack(alignment: .leading, spacing: 2) {
                labeledSlider(
                    title: "어둡기 임계값" + (parameters.useAutoCalibration ? " (자동 보정 중에는 무시됨)" : ""),
                    value: Binding(
                        get: { Double(parameters.darkPixelThreshold) },
                        set: { parameters.darkPixelThreshold = UInt8($0) }
                    ),
                    range: 60...200,
                    format: "%.0f"
                )
            }
            .disabled(parameters.useAutoCalibration)
            .opacity(parameters.useAutoCalibration ? 0.4 : 1.0)

            labeledSlider(title: "오선 판정 비율", value: $parameters.minStaffLineDarkRatio, range: 0.2...0.9, format: "%.2f")

            labeledSlider(title: "오선 간격 허용오차", value: $parameters.staffSpacingTolerance, range: 0.05...0.6, format: "%.2f")

            labeledSlider(
                title: "System 묶기 간격(오선 간격 배수)",
                value: $parameters.systemGroupingMaxGapInStaffSpaces,
                range: 1.0...15.0,
                format: "%.1f"
            )

            labeledSlider(title: "마디선 판정 비율", value: $parameters.minBarlineDarkRatio, range: 0.2...0.95, format: "%.2f")

            labeledSlider(
                title: "마디선 최소 간격(px)",
                value: Binding(
                    get: { Double(parameters.minBarlineSeparationPx) },
                    set: { parameters.minBarlineSeparationPx = Int($0) }
                ),
                range: 2...40,
                format: "%.0f"
            )

            labeledSlider(
                title: "마디선 최대 두께 배수 (오선 두께 대비)",
                value: $parameters.barlineMaxThicknessMultiplier,
                range: 1.5...10.0,
                format: "%.1f"
            )

            labeledSlider(
                title: "최소 마디 너비(px)",
                value: Binding(
                    get: { Double(parameters.minMeasureWidthPx) },
                    set: { parameters.minMeasureWidthPx = Int($0) }
                ),
                range: 5...80,
                format: "%.0f"
            )

            HStack(spacing: 10) {
                Button(action: onReanalyze) {
                    Label("다시 인식하기", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    parameters = .default
                    onReanalyze()
                } label: {
                    Label("기본값", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func labeledSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
