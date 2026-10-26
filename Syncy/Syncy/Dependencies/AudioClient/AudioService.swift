//
//  AudioService.swift
//  Syncy
//
//  Created by anna on 10/22/26.
//

import AVFoundation
import Foundation

/// 오디오 명령과 상태를 한 곳에서 순서대로 처리한다. 실제 렌더링은 엔진이 담당한다.
@MainActor
final class AudioService: NSObject, AVAudioRecorderDelegate {
    private final class Track {
        let file: AVAudioFile
        let node = AVAudioPlayerNode()
        let pitch = AVAudioUnitTimePitch()
        var volume: Float = 1
        var isMuted = false

        init(file: AVAudioFile) { self.file = file }
    }

    private final class PatchPlayer {
        let patch: Patch
        let file: AVAudioFile
        let node = AVAudioPlayerNode()
        let pitch = AVAudioUnitTimePitch()

        init(patch: Patch, file: AVAudioFile) {
            self.patch = patch
            self.file = file
        }
    }

    private struct Recording {
        let recorder: AVAudioRecorder
        let trackID: SessionID
        let range: ClosedRange<TimeInterval>
        var previousRate: Float
        var previousLoop: ClosedRange<TimeInterval>?
        let previousSolo: SessionID?
    }

    private let engine = AVAudioEngine()
    private let clickNode = AVAudioPlayerNode()
    private let metronomeNode = AVAudioPlayerNode()
    private let clickFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var tracks: [SessionID: Track] = [:]
    private var patches: [UUID: PatchPlayer] = [:]
    private var duration: TimeInterval = 0
    private var rate: Float = 1
    private var soloTrackID: SessionID?
    private var loopRange: ClosedRange<TimeInterval>?
    private var isPlaying = false
    private var pausedPosition: TimeInterval = 0
    private var startPosition: TimeInterval = 0
    private var hostAnchor: TimeInterval = 0
    private var elapsedAtAnchor: TimeInterval = 0
    private var playbackLoop: ClosedRange<TimeInterval>?
    private var scheduledUntil: TimeInterval = 0
    private var wrappedLoops = 0
    private var recording: Recording?
    private var pendingRecordingID: UUID?
    private var monitor: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var eventSubscribers: [UUID: AsyncStream<AudioEvent>.Continuation] = [:]
    private var positionSubscribers: [UUID: AsyncStream<TimeInterval>.Continuation] = [:]
    private var lastPublishedPosition: TimeInterval?

    override init() {
        super.init()
        for node in [clickNode, metronomeNode] {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: clickFormat)
        }
    }

    deinit {
        monitor?.cancel()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for subscriber in eventSubscribers.values { subscriber.finish() }
        for subscriber in positionSubscribers.values { subscriber.finish() }
    }

    // MARK: - 곡 로드 · 재생

    func load(_ songTracks: [SongTrack]) async throws -> TimeInterval {
        try Task.checkCancellation()
        guard !songTracks.isEmpty else { throw AudioServiceError.noTracks }
        var loaded: [SessionID: Track] = [:]
        for songTrack in songTracks {
            guard loaded[songTrack.id] == nil else { throw AudioServiceError.invalidAudio }
            let file = try AVAudioFile(forReading: songTrack.fileURL)
            guard file.length > 0, file.processingFormat.sampleRate > 0 else {
                throw AudioServiceError.invalidAudio
            }
            loaded[songTrack.id] = Track(file: file)
        }
        try Task.checkCancellation()
        try configureSession()
        cancelRecording()
        pause()
        for player in patches.values { detach(player.node, player.pitch) }
        for track in tracks.values { detach(track.node, track.pitch) }
        patches = [:]
        tracks = loaded
        rate = 1
        loopRange = nil
        soloTrackID = nil
        pausedPosition = 0
        duration = loaded.values.map { Double($0.file.length) / $0.file.processingFormat.sampleRate }.max() ?? 0
        for track in tracks.values { attach(track.node, track.pitch, file: track.file) }
        applyMix()
        try startEngine()
        publishPosition()
        return duration
    }

    func play() throws {
        try Task.checkCancellation()
        guard !tracks.isEmpty else { throw AudioServiceError.noTracks }
        guard !isPlaying else { return }
        try configureSession()
        try startPlayback(from: pausedPosition >= duration ? 0 : pausedPosition)
    }

    func pause() {
        guard isPlaying else { return }
        pausedPosition = currentPosition
        isPlaying = false
        stopNodes()
        publishPosition()
        updateMonitor()
    }

    func seek(_ time: TimeInterval) {
        guard time.isFinite, recording == nil else { return }
        let target = min(max(time, 0), duration)
        let resume = isPlaying
        pause()
        pausedPosition = target
        if resume { restart(from: target) }
        publishPosition()
    }

    func setRate(_ value: Float) {
        guard value.isFinite, value > 0 else { return }
        let newRate = min(max(value, 1.0 / 32), 32)
        if recording != nil {
            recording?.previousRate = newRate
            return
        }
        if isPlaying, hostTime >= hostAnchor {
            elapsedAtAnchor = elapsed
            hostAnchor = hostTime
        }
        rate = newRate
        for track in tracks.values { track.pitch.rate = rate }
        for player in patches.values { player.pitch.rate = rate }
    }

    func setLoop(_ range: ClosedRange<TimeInterval>?) {
        if let range {
            guard validRange(range) else { return }
        }
        if recording != nil {
            recording?.previousLoop = range
            return
        }
        let position = currentPosition
        let resume = isPlaying
        pause()
        loopRange = range
        if resume { restart(from: position) }
    }

    // MARK: - 믹서

    func setVolume(_ id: SessionID, _ volume: Float) {
        guard volume.isFinite else { return }
        tracks[id]?.volume = min(max(volume, 0), 1)
        applyMix()
    }

    func setMuted(_ id: SessionID, _ muted: Bool) {
        tracks[id]?.isMuted = muted
        applyMix()
    }

    func setSolo(_ id: SessionID?) {
        if let id, tracks[id] == nil { return }
        soloTrackID = id
        applyMix()
    }

    private func applyMix() {
        for (id, track) in tracks {
            let audible = recording?.trackID != id && (soloTrackID.map { $0 == id } ?? !track.isMuted)
            let volume = audible ? track.volume : 0
            track.node.volume = volume
            for player in patches.values where player.patch.sessionId == id {
                player.node.volume = volume
            }
        }
    }

    // MARK: - 패치

    func activatePatch(_ patch: Patch, file url: URL) -> Bool {
        guard recording == nil, tracks[patch.sessionId] != nil,
              patch.startTime.isFinite, patch.endTime.isFinite,
              patch.sourceStart.isFinite, patch.sourceStart >= 0,
              patch.startTime >= 0, patch.endTime <= duration,
              patch.startTime < patch.endTime,
              let file = try? AVAudioFile(forReading: url),
              patch.sourceStart + patch.endTime - patch.startTime <= Double(file.length + 1) / file.processingFormat.sampleRate
        else { return false }

        let position = currentPosition
        let resume = isPlaying
        pause()
        let overlaps = patches.values.filter {
            $0.patch.id == patch.id || ($0.patch.sessionId == patch.sessionId
                && $0.patch.startTime < patch.endTime && patch.startTime < $0.patch.endTime)
        }.map { $0.patch.id }
        for id in overlaps { removePatch(id) }
        let player = PatchPlayer(patch: patch, file: file)
        patches[patch.id] = player
        attach(player.node, player.pitch, file: file)
        applyMix()
        if resume { restart(from: position) }
        return true
    }

    func deactivatePatch(_ id: UUID, trackID: SessionID) {
        guard patches[id]?.patch.sessionId == trackID else { return }
        let position = currentPosition
        let resume = isPlaying
        pause()
        removePatch(id)
        if resume { restart(from: position) }
    }

    private func removePatch(_ id: UUID) {
        guard let player = patches.removeValue(forKey: id) else { return }
        detach(player.node, player.pitch)
    }

    // MARK: - 녹음

    func requestRecordingPermission() async throws {
        try Task.checkCancellation()
        guard let description = Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String,
              !description.isEmpty else { throw AudioServiceError.missingMicrophoneDescription }
        let permitted = await AVAudioApplication.requestRecordPermission()
        try Task.checkCancellation()
        guard permitted else { throw AudioServiceError.microphoneDenied }
    }

    func startRecording(_ trackID: SessionID, range: ClosedRange<TimeInterval>) async throws {
        try Task.checkCancellation()
        guard tracks[trackID] != nil else { throw AudioServiceError.noTracks }
        guard validRange(range) else { throw AudioServiceError.invalidRange }
        guard recording == nil, pendingRecordingID == nil else { throw AudioServiceError.alreadyRecording }
        let requestID = UUID()
        pendingRecordingID = requestID
        defer { if pendingRecordingID == requestID { pendingRecordingID = nil } }
        try await requestRecordingPermission()
        guard pendingRecordingID == requestID else { throw CancellationError() }
        try configureSession()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).m4a")
        let recorder = try AVAudioRecorder(url: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ])
        recorder.delegate = self
        guard recorder.prepareToRecord() else {
            recorder.deleteRecording()
            throw AudioServiceError.cannotRecord
        }
        pause()
        recording = Recording(recorder: recorder, trackID: trackID, range: range,
                              previousRate: rate, previousLoop: loopRange, previousSolo: soloTrackID)
        loopRange = nil
        soloTrackID = nil
        // setRate는 녹음 중 설정 변경을 보관하므로, 실제 엔진에는 직접 원래 속도를 적용한다.
        rate = 1
        for track in tracks.values { track.pitch.rate = 1 }
        for player in patches.values { player.pitch.rate = 1 }
        applyMix()
        do {
            try startPlayback(from: range.lowerBound)
        } catch {
            cancelRecording()
            throw error
        }
    }

    func stopRecording() throws -> URL {
        try Task.checkCancellation()
        guard let recording else { throw AudioServiceError.notRecording }
        let url = recording.recorder.url
        finishRecording()
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else {
            recording.recorder.deleteRecording()
            throw AudioServiceError.cannotRecord
        }
        return url
    }

    func cancelRecording() {
        pendingRecordingID = nil
        guard let recording else { return }
        finishRecording()
        recording.recorder.deleteRecording()
    }

    private func finishRecording() {
        guard let saved = recording else { return }
        pause()
        saved.recorder.delegate = nil
        saved.recorder.stop()
        recording = nil
        setRate(saved.previousRate)
        loopRange = saved.previousLoop
        soloTrackID = saved.previousSolo
        applyMix()
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        let url = recorder.url
        let reason = error?.localizedDescription ?? "녹음 파일을 만들지 못했어요."
        Task { @MainActor [weak self] in self?.recordingFailed(url: url, reason: reason) }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard !flag else { return }
        let url = recorder.url
        Task { @MainActor [weak self] in
            self?.recordingFailed(url: url, reason: "녹음이 예기치 않게 종료됐어요.")
        }
    }

    private func recordingFailed(url: URL, reason: String) {
        guard recording?.recorder.url == url else { return }
        cancelRecording()
        emit(.recordingFailed(reason: reason))
    }

    // MARK: - 카운트인 · 메트로놈

    func click(_ accent: Bool) {
        do {
            try configureSession()
            try startEngine()
            guard let buffer = clickBuffer(accent: accent) else { return }
            clickNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
            if !clickNode.isPlaying { clickNode.play() }
        } catch { interrupt() }
    }

    /// 문서의 메트로놈 볼륨 범위(0~100)를 Float로 받는다.
    func setMetronome(_ on: Bool, bpm: Double, volume: Float) {
        metronomeNode.stop()
        guard on, bpm.isFinite, bpm > 0, volume.isFinite else { return }
        let frames = clickFormat.sampleRate * 60 / bpm
        // 비정상 BPM으로 지나치게 큰 버퍼가 할당되는 것을 막는다(한 마디 최대 60초).
        guard frames >= 1, frames <= clickFormat.sampleRate * 15 else { return }
        let perBeat = Int(frames.rounded())
        guard let bar = AVAudioPCMBuffer(pcmFormat: clickFormat, frameCapacity: AVAudioFrameCount(perBeat * 4)),
              let samples = bar.floatChannelData?[0] else { return }
        bar.frameLength = bar.frameCapacity
        samples.initialize(repeating: 0, count: Int(bar.frameLength))
        for beat in 0..<4 {
            guard let click = clickBuffer(accent: beat == 0), let source = click.floatChannelData?[0] else { return }
            for index in 0..<min(perBeat, Int(click.frameLength)) {
                samples[beat * perBeat + index] = source[index]
            }
        }
        do {
            try configureSession()
            try startEngine()
            metronomeNode.volume = min(max(volume, 0), 100) / 100
            metronomeNode.scheduleBuffer(bar, at: nil, options: .loops)
            metronomeNode.play()
        } catch { interrupt() }
    }

    private func clickBuffer(accent: Bool) -> AVAudioPCMBuffer? {
        let count = 1_323
        guard let buffer = AVAudioPCMBuffer(pcmFormat: clickFormat, frameCapacity: AVAudioFrameCount(count)),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = buffer.frameCapacity
        for index in 0..<count {
            let fade = 1 - Double(index) / Double(count)
            let phase = 2 * Double.pi * (accent ? 1_600 : 1_000) * Double(index) / clickFormat.sampleRate
            samples[index] = Float(sin(phase) * fade * (accent ? 0.8 : 0.5))
        }
        return buffer
    }

    // MARK: - 이벤트 · 재생 위치

    func events() -> AsyncStream<AudioEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<AudioEvent>.makeStream()
        eventSubscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in self?.eventSubscribers[id] = nil }
        }
        return stream
    }

    func position() -> AsyncStream<TimeInterval> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<TimeInterval>.makeStream(bufferingPolicy: .bufferingNewest(1))
        positionSubscribers[id] = continuation
        continuation.yield(currentPosition)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.positionSubscribers[id] = nil
                self?.updateMonitor()
            }
        }
        updateMonitor()
        return stream
    }

    private func emit(_ event: AudioEvent) {
        for subscriber in eventSubscribers.values { subscriber.yield(event) }
    }

    private func publishPosition() {
        let position = currentPosition
        guard position != lastPublishedPosition else { return }
        lastPublishedPosition = position
        for subscriber in positionSubscribers.values { subscriber.yield(position) }
    }

    private var hostTime: TimeInterval { AVAudioTime.seconds(forHostTime: mach_absolute_time()) }
    private var elapsed: TimeInterval {
        elapsedAtAnchor + max(0, hostTime - hostAnchor) * Double(rate)
    }

    private var currentPosition: TimeInterval {
        guard isPlaying else { return pausedPosition }
        guard let range = playbackLoop else { return min(startPosition + elapsed, duration) }
        let firstLength = range.upperBound - startPosition
        if elapsed < firstLength { return startPosition + elapsed }
        return range.lowerBound + (elapsed - firstLength).truncatingRemainder(dividingBy: range.upperBound - range.lowerBound)
    }

    private func updateMonitor() {
        guard isPlaying || !positionSubscribers.isEmpty else {
            monitor?.cancel()
            monitor = nil
            return
        }
        guard monitor == nil else { return }
        monitor = Task { @MainActor [weak self] in
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .milliseconds(30))
                    guard let self else { return }
                    self.tick()
                }
            } catch { /* 구독 종료 또는 재생 정지로 취소 */ }
        }
    }

    private func tick() {
        if isPlaying, let range = playbackLoop {
            let firstLength = range.upperBound - startPosition
            let length = range.upperBound - range.lowerBound
            let wraps = elapsed < firstLength ? 0 : 1 + Int((elapsed - firstLength) / length)
            while wrappedLoops < wraps {
                wrappedLoops += 1
                emit(.loopWrapped)
                // 끝나기 전에 다음 바퀴를 추가해서 노드를 멈추지 않고 반복한다.
                schedulePass(from: range.lowerBound, to: range.upperBound, offset: scheduledUntil)
                scheduledUntil += length
            }
        } else if isPlaying, startPosition + elapsed >= duration {
            pausedPosition = duration
            isPlaying = false
            stopNodes()
            publishPosition()
            emit(.playbackEnded)
            updateMonitor()
        }
        publishPosition()
    }

    // MARK: - 엔진 내부

    private func validRange(_ range: ClosedRange<TimeInterval>) -> Bool {
        range.lowerBound.isFinite && range.upperBound.isFinite && range.lowerBound >= 0
            && range.upperBound <= duration && range.upperBound > range.lowerBound
    }

    private func attach(_ node: AVAudioPlayerNode, _ pitch: AVAudioUnitTimePitch, file: AVAudioFile) {
        engine.attach(node)
        engine.attach(pitch)
        engine.connect(node, to: pitch, format: file.processingFormat)
        engine.connect(pitch, to: engine.mainMixerNode, format: file.processingFormat)
        pitch.rate = rate
    }

    private func detach(_ node: AVAudioPlayerNode, _ pitch: AVAudioUnitTimePitch) {
        node.stop()
        engine.detach(node)
        engine.detach(pitch)
    }

    private func stopNodes() {
        for track in tracks.values { track.node.stop() }
        for player in patches.values { player.node.stop() }
    }

    private func startEngine() throws {
        guard !engine.isRunning else { return }
        engine.prepare()
        try engine.start()
    }

    private func startPlayback(from position: TimeInterval) throws {
        stopNodes()
        try startEngine()
        playbackLoop = loopRange
        startPosition = loopRange.map { $0.contains(position) && position < $0.upperBound ? position : $0.lowerBound } ?? position
        scheduledUntil = 0
        wrappedLoops = 0
        if let range = playbackLoop {
            schedulePass(from: startPosition, to: range.upperBound, offset: 0)
            scheduledUntil = range.upperBound - startPosition
            for _ in 0..<2 {
                schedulePass(from: range.lowerBound, to: range.upperBound, offset: scheduledUntil)
                scheduledUntil += range.upperBound - range.lowerBound
            }
        } else {
            schedulePass(from: startPosition, to: duration, offset: 0)
        }
        let lead: TimeInterval = 0.1
        let hostStart = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: lead)
        if let recording {
            guard recording.recorder.record(atTime: recording.recorder.deviceCurrentTime + lead) else {
                throw AudioServiceError.cannotRecord
            }
        }
        let time = AVAudioTime(hostTime: hostStart)
        for track in tracks.values { track.node.play(at: time) }
        for player in patches.values { player.node.play(at: time) }
        hostAnchor = AVAudioTime.seconds(forHostTime: hostStart)
        elapsedAtAnchor = 0
        isPlaying = true
        updateMonitor()
        publishPosition()
    }

    private func restart(from position: TimeInterval) {
        do { try startPlayback(from: position) }
        catch { interrupt() }
    }

    private func schedulePass(from start: TimeInterval, to end: TimeInterval, offset: TimeInterval) {
        guard start < end else { return }
        for (id, track) in tracks {
            var cursor = start
            for player in patches.values.filter({ $0.patch.sessionId == id }).sorted(by: { $0.patch.startTime < $1.patch.startTime }) {
                let lower = max(start, player.patch.startTime)
                let upper = min(end, player.patch.endTime)
                guard lower < upper else { continue }
                schedule(track.node, file: track.file, source: cursor, length: lower - cursor, offset: offset + cursor - start)
                schedule(player.node, file: player.file, source: player.patch.sourceStart + lower - player.patch.startTime,
                         length: upper - lower, offset: offset + lower - start)
                cursor = upper
            }
            schedule(track.node, file: track.file, source: cursor, length: end - cursor, offset: offset + cursor - start)
        }
    }

    private func schedule(_ node: AVAudioPlayerNode, file: AVAudioFile, source: TimeInterval, length: TimeInterval, offset: TimeInterval) {
        guard length > 0 else { return }
        let sampleRate = file.processingFormat.sampleRate
        let first = AVAudioFramePosition((source * sampleRate).rounded())
        guard first >= 0, first < file.length else { return }
        var remaining = min(AVAudioFramePosition((length * sampleRate).rounded()), file.length - first)
        var consumed: AVAudioFramePosition = 0
        while remaining > 0 {
            let count = AVAudioFrameCount(min(remaining, AVAudioFramePosition(UInt32.max)))
            let time = AVAudioTime(sampleTime: AVAudioFramePosition((offset * sampleRate).rounded()) + consumed, atRate: sampleRate)
            node.scheduleSegment(file, startingFrame: first + consumed, frameCount: count, at: time)
            remaining -= AVAudioFramePosition(count)
            consumed += AVAudioFramePosition(count)
        }
    }

    private func configureSession() throws {
        if observers.isEmpty { installObservers() }
        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        }
        try session.setActive(true)
    }

    private func installObservers() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in self?.interrupt() }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor [weak self] in self?.interrupt() }
        })
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying, !self.engine.isRunning else { return }
                self.interrupt()
            }
        })
    }

    private func interrupt() {
        let wasRecording = recording != nil
        cancelRecording()
        pause()
        clickNode.stop()
        metronomeNode.stop()
        emit(.interrupted)
        if wasRecording { emit(.recordingFailed(reason: "오디오가 중단되어 녹음을 취소했어요.")) }
    }
}
