//
//  SyncService.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

struct SyncService: Sendable {

    func send(ops: [SyncOp]) async throws {
        try? await Task.sleep(for: .milliseconds(500))
    }

    func pull(sinceVersion: Int?) async throws -> RemoteState? {
        try? await Task.sleep(for: .milliseconds(500))
        return nil
    }

    func uploadAudio(patchID: UUID, file: URL) async throws {
        try? await Task.sleep(for: .milliseconds(500))
    }

    func downloadAudio(patchID: UUID) async throws -> URL {
        try? await Task.sleep(for: .milliseconds(500))
        return FileManager.default.temporaryDirectory.appendingPathComponent("\(patchID.uuidString).m4a")
    }
}
