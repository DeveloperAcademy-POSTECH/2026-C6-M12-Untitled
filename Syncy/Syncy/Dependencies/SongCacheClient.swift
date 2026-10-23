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
    var store: (_ tempFile: Data, _ jobID: String, _ stem: SessionID) async throws -> URL
}

// Conform to DependencyKey to provide a live implementation of
// the interface.
extension SongCacheClient: DependencyKey{
    static let liveValue = Self(
        store: { data, jobID, stem in
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(jobID)_\(stem.rawValue).mp3")
            try? data.write(to: tempURL)
            return tempURL
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
