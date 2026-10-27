//
//  SongCacheClient.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct SongCacheClient {
    var store: (_ tempFile: URL, _ jobID: String, _ stem: SessionID) async throws -> URL
    // 2차에서 추가 (설정 화면이 씀)
    var totalSize: () async throws -> Int
    var removeAll: () async throws -> Void
}

// Conform to DependencyKey to provide a live implementation of
// the interface.
extension SongCacheClient: DependencyKey{
    // liveValue는 Service에 일을 넘기기만 한다.
    static let liveValue: SongCacheClient = {
        let service = SongCacheService()
        return Self(
            store: { tempFile, jobID, stem in
                try await service.store(tempFile: tempFile, jobID: jobID, stem: stem)
            },
            totalSize: {
                try await service.totalSize()
            },
            removeAll: {
                try await service.removeAll()
            }
        )
    }()
}

// Register the dependency within DependencyValues.
extension DependencyValues {
  var songCacheClient: SongCacheClient {
    get { self[SongCacheClient.self] }
    set { self[SongCacheClient.self] = newValue }
  }
}
