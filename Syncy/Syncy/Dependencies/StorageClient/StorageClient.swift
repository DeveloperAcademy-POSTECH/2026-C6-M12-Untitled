//
//  StorageClient.swift
//  Syncy
//
//  Created by moo on 10/22/26.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct StorageClient {
    var loadFeedback: (_ songID: String) async throws -> [FeedbackItem]
    var saveFeedback: (_ songID: String, _ items: [FeedbackItem]) async throws -> Void
    var loadPatches: (_ songID: String) async throws -> [Patch]
    var savePatches: (_ songID: String, _ patches: [Patch]) async throws -> Void
    var savePatchFile: (_ tempFile: Data, _ patchID: UUID, _ songID: String) async throws -> URL
    var patchFileURL: (_ patchID: UUID, _ songID: String) -> URL = { _, _ in FileManager.default.temporaryDirectory }
}

// liveValue는 Service에 일을 넘기기만.
extension StorageClient: DependencyKey {
    static let liveValue: StorageClient = {
        let service = StorageService()
        return Self(
            loadFeedback: { songID in
                try await service.loadFeedback(songID: songID)
            },
            saveFeedback: { songID, items in
                try await service.saveFeedback(songID: songID, items: items)
            },
            loadPatches: { songID in
                try await service.loadPatches(songID: songID)
            },
            savePatches: { songID, patches in
                try await service.savePatches(songID: songID, patches: patches)
            },
            savePatchFile: { tempFile, patchID, songID in
                try await service.savePatchFile(tempFile: tempFile, patchID: patchID, songID: songID)
            },
            patchFileURL: { patchID, songID in
                service.patchFileURL(patchID: patchID, songID: songID)
            }
        )
    }()

    // 목데이터 Service라서 previewValue는 liveValue와 같음. 진짜 저장이 구현되면 분리
    static let previewValue = liveValue
    static let testValue = Self()
}

extension DependencyValues {
    var storageClient: StorageClient {
        get { self[StorageClient.self] }
        set { self[StorageClient.self] = newValue }
    }
}
