//
//  SyncClient.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct SyncClient {
    var send: (_ ops: [SyncOp]) async throws -> Void
    var pull: (_ sinceVersion: Int?) async throws -> RemoteState?
    var uploadAudio: (_ patchID: UUID, _ file: URL) async throws -> Void
    var downloadAudio: (_ patchID: UUID) async throws -> URL
}

extension SyncClient: DependencyKey {
    static let liveValue: SyncClient = {
        let service = SyncService()
        return Self(
            send: { ops in
                try await service.send(ops: ops)
            },
            pull: { sinceVersion in
                try await service.pull(sinceVersion: sinceVersion)
            },
            uploadAudio: { patchID, file in
                try await service.uploadAudio(patchID: patchID, file: file)
            },
            downloadAudio: { patchID in
                try await service.downloadAudio(patchID: patchID)
            }
        )
    }()

    static let testValue = Self()
}

extension DependencyValues {
    var syncClient: SyncClient {
        get { self[SyncClient.self] }
        set { self[SyncClient.self] = newValue }
    }
}
