//
//  AudioClient.swift
//  Syncy
//
//  Created by martin on 10/22/26.
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
    var startRecording: (_ trackID: SessionID, _ range: ClosedRange<TimeInterval>) async throws -> Void
    var stopRecording: () async throws -> URL
    var cancelRecording: () async -> Void
    var click: (_ accent: Bool) async -> Void
    var setMetronome: (_ on: Bool, _ bpm: Double, _ volume: Float) async -> Void
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
