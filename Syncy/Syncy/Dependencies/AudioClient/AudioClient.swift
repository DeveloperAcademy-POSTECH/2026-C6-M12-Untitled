//
//  AudioClient.swift
//  Syncy
//
//  Created by anna on 10/22/26.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct AudioClient {
    var load: (_ tracks: [SongTrack]) async throws -> TimeInterval
    var play: () async throws -> Void
    var pause: () async -> Void
    var seek: (_ time: TimeInterval) async -> Void
    var setRate: (_ rate: Float) async -> Void
    var setLoop: (_ range: ClosedRange<TimeInterval>?) async -> Void
    var setVolume: (_ trackID: SessionID, _ volume: Float) async -> Void
    var setMuted: (_ trackID: SessionID, _ muted: Bool) async -> Void
    var setSolo: (_ trackID: SessionID?) async -> Void
    var activatePatch: (_ patch: Patch, _ file: URL) async -> Bool = { _, _ in false }
    var deactivatePatch: (_ patchID: UUID, _ trackID: SessionID) async -> Void
    var requestRecordingPermission: () async throws -> Void
    var startRecording: (_ trackID: SessionID, _ range: ClosedRange<TimeInterval>) async throws -> Void
    var stopRecording: () async throws -> URL
    var cancelRecording: () async -> Void
    var click: (_ accent: Bool) async -> Void
    /// volume은 설계의 메트로놈 볼륨 범위인 0~100이다.
    var setMetronome: (_ on: Bool, _ bpm: Int, _ volume: Float) async -> Void
    var events: () async -> AsyncStream<AudioEvent> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    var position: () async -> AsyncStream<TimeInterval> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

extension AudioClient: DependencyKey {
    static let liveValue: Self = {
        let service = AudioService()
        return Self(
            load: { try await service.load($0) },
            play: { try service.play() },
            pause: { service.pause() },
            seek: { service.seek($0) },
            setRate: { service.setRate($0) },
            setLoop: { service.setLoop($0) },
            setVolume: { service.setVolume($0, $1) },
            setMuted: { service.setMuted($0, $1) },
            setSolo: { service.setSolo($0) },
            activatePatch: { service.activatePatch($0, file: $1) },
            deactivatePatch: { service.deactivatePatch($0, trackID: $1) },
            requestRecordingPermission: { try await service.requestRecordingPermission() },
            startRecording: { try await service.startRecording($0, range: $1) },
            stopRecording: { try service.stopRecording() },
            cancelRecording: { service.cancelRecording() },
            click: { service.click($0) },
            setMetronome: { service.setMetronome($0, bpm: $1, volume: $2) },
            events: { service.events() },
            position: { service.position() }
        )
    }()

    static let testValue = Self()
}

extension DependencyValues {
    var audioClient: AudioClient {
        get { self[AudioClient.self] }
        set { self[AudioClient.self] = newValue }
    }
}
