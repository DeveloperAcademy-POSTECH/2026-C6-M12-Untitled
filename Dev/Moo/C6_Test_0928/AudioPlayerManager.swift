import Foundation
import AVFoundation
import Combine

/// Thin ObservableObject wrapper around AVAudioPlayer: owns the player instance,
/// publishes playback time on a timer so SwiftUI can redraw the scrubber and the
/// "now playing" measure highlight, and exposes seek/play/pause as plain methods.
@MainActor
final class AudioPlayerManager: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var fileName: String = ""
    @Published var loadErrorMessage: String?

    private var player: AVAudioPlayer?
    private var pollTask: Task<Void, Never>?

    func load(url: URL) {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }

        stopTimer()
        do {
            let data = try Data(contentsOf: url)
            let newPlayer = try AVAudioPlayer(data: data)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            player = newPlayer
            duration = newPlayer.duration
            currentTime = 0
            isPlaying = false
            fileName = url.lastPathComponent
            loadErrorMessage = nil
        } catch {
            player = nil
            duration = 0
            fileName = ""
            loadErrorMessage = "오디오를 불러오지 못했어요: \(error.localizedDescription)"
        }
    }

    var hasAudio: Bool { player != nil }

    /// Clears the loaded track entirely. Called when a *different* score PDF is
    /// imported: without this, the previously-loaded recording (and its playback
    /// position) stayed attached to the new, unrelated score, so the "now playing"
    /// measure highlight would silently compute nonsense against a piece it was
    /// never synced to. Re-importing audio for the new score is a small ask compared
    /// to a confusing mismatch that looks like a sync bug.
    func unload() {
        stopTimer()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        fileName = ""
        loadErrorMessage = nil
    }

    func play() {
        guard let player else { return }
        configureSessionIfNeeded()
        player.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    /// Seeks to `time` (seconds) and starts playing, e.g. when the user taps a measure
    /// on the score to jump straight to that part of the recording.
    func seekAndPlay(to time: Double) {
        guard let player else { return }
        player.currentTime = max(0, min(time, player.duration))
        currentTime = player.currentTime
        play()
    }

    func seek(to time: Double) {
        guard let player else { return }
        player.currentTime = max(0, min(time, player.duration))
        currentTime = player.currentTime
    }

    private func configureSessionIfNeeded() {
        #if canImport(AVFAudio)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    private func startTimer() {
        stopTimer()
        // 20fps is plenty for a scrubber/measure highlight and cheap enough to run
        // continuously while a rehearsal recording plays. A structured Task inherits
        // this @MainActor class's isolation, so `tick()` needs no explicit actor hop
        // (unlike a Timer closure, which Swift 6 flags for capturing `self` across an
        // unproven concurrency domain).
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                self.tick()
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }

    private func stopTimer() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func tick() {
        guard let player else { return }
        currentTime = player.currentTime
        if !player.isPlaying {
            isPlaying = false
            stopTimer()
        }
    }
}

extension AudioPlayerManager: @preconcurrency AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
}
