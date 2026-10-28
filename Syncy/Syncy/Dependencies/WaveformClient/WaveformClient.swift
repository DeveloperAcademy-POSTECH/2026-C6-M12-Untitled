import ComposableArchitecture
import Foundation

nonisolated struct WaveformPeaks: Equatable, Sendable {
    let samples: [Float]
    let duration: TimeInterval
}

@DependencyClient
struct WaveformClient {
    var peaks: (_ fileURL: URL, _ count: Int) async throws -> WaveformPeaks
}

extension WaveformClient: DependencyKey {
    static let liveValue = Self(peaks: { fileURL, count in
        try await WaveformService.peaks(fileURL: fileURL, count: count)
    })
    static let previewValue = Self(peaks: { _, _ in
        WaveformPeaks(samples: [], duration: 0)
    })
    static let testValue = Self()
}

extension DependencyValues {
    var waveformClient: WaveformClient {
        get { self[WaveformClient.self] }
        set { self[WaveformClient.self] = newValue }
    }
}
