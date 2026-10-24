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
}

// Conform to DependencyKey to provide a live implementation of
// the interface.
extension SongCacheClient: DependencyKey{
    static let liveValue = Self(
        store: { tempFile, _, _ in
            // 아직 가짜: 받은 임시 파일을 그대로 돌려준다. 영구 위치로 옮기는 건 SongCacheService에서.
            tempFile
        },
    )
}

// Register the dependency within DependencyValues.
extension DependencyValues {
  var songCacheClient: SongCacheClient {
    get { self[SongCacheClient.self] }
    set { self[SongCacheClient.self] = newValue }
  }
}
