//
//  ShowClient.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct ShowClient {
    var shows: (_ bandID: UUID) async throws -> [Show]
    // 반환 타입 미정
    var createShow: (_ draft: ShowDraft) async throws -> Void
    var updateShow: (_ show: Show) async throws -> Void
    var deleteShow: (_ id: UUID) async throws -> Void
    var setlist: (_ showID: UUID) async throws -> [SongSummary]
    var reorder: (_ showID: UUID, _ songIDs: [String]) async throws -> Void
    var moveSong: (_ songID: String, _ toShowID: UUID) async throws -> Void
    var deleteSong: (_ songID: String) async throws -> Void
}

// liveValue는 Service에 일을 넘기기만 한다.
extension ShowClient: DependencyKey {
    static let liveValue: ShowClient = {
        let service = ShowService()
        return Self(
            shows: { bandID in
                try await service.shows(bandID: bandID)
            },
            createShow: { draft in
                try await service.createShow(draft: draft)
            },
            updateShow: { show in
                try await service.updateShow(show: show)
            },
            deleteShow: { id in
                try await service.deleteShow(id: id)
            },
            setlist: { showID in
                try await service.setlist(showID: showID)
            },
            reorder: { showID, songIDs in
                try await service.reorder(showID: showID, songIDs: songIDs)
            },
            moveSong: { songID, toShowID in
                try await service.moveSong(songID: songID, toShowID: toShowID)
            },
            deleteSong: { songID in
                try await service.deleteSong(songID: songID)
            }
        )
    }()

    // 목데이터 Service라서 previewValue는 liveValue와 같음. 진짜 저장이 구현되면 분리
    static let previewValue = liveValue
    static let testValue = Self()
}

extension DependencyValues {
    var showClient: ShowClient {
        get { self[ShowClient.self] }
        set { self[ShowClient.self] = newValue }
    }
}
