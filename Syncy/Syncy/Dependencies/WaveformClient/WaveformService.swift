import Accelerate
import AVFoundation
import Foundation

nonisolated enum WaveformService {
    static func peaks(fileURL: URL, count: Int) async throws -> WaveformPeaks {
        let task = Task.detached(priority: .utility) {
            try readPeaks(fileURL: fileURL, count: count)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func readPeaks(fileURL: URL, count: Int) throws -> WaveformPeaks {
        try Task.checkCancellation()
        guard count > 0 else { throw ReadError.invalidAudio }
        let file = try AVAudioFile(forReading: fileURL, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        guard file.length > 0, format.sampleRate.isFinite, format.sampleRate > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_384) else {
            throw ReadError.invalidAudio
        }

        let total = file.length
        let binCount = min(count, Int(total))
        var samples = [Float](repeating: 0, count: binCount)
        var offset: AVAudioFramePosition = 0

        while offset < total {
            try Task.checkCancellation()
            let bin = min(binCount - 1, Int(offset * Int64(binCount) / total))
            let end = (Int64(bin + 1) * total + Int64(binCount) - 1) / Int64(binCount)
            let length = AVAudioFrameCount(min(Int64(buffer.frameCapacity), end - offset))
            try file.read(into: buffer, frameCount: length)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else {
                throw ReadError.invalidAudio
            }
            for channel in 0..<Int(format.channelCount) {
                var peak: Float = 0
                vDSP_maxmgv(channels[channel], 1, &peak, vDSP_Length(buffer.frameLength))
                if peak.isFinite { samples[bin] = max(samples[bin], peak) }
            }
            offset += Int64(buffer.frameLength)
        }

        let maximum = samples.max() ?? 0
        if maximum > 0 { samples = samples.map { $0 / maximum } }
        return WaveformPeaks(samples: samples, duration: Double(total) / format.sampleRate)
    }

    private enum ReadError: LocalizedError {
        case invalidAudio

        var errorDescription: String? { "음원에서 파형을 읽을 수 없어요." }
    }
}
