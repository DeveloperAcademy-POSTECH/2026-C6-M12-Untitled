//
//  ShowService.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

// 공연 · 셋리스트를 다루는 곳. ShowClient의 liveValue가 이걸 부름.
// 일단 전부 목데이터로
struct ShowService: Sendable {
    func shows(bandID: UUID) async throws -> [Show] {
        try? await Task.sleep(for: .milliseconds(500))
        return []   // 목데이터: 공연 없음
    }

    func createShow(draft: ShowDraft) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 만들지 않음
    }

    func updateShow(show: Show) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 저장하지 않음
    }

    func deleteShow(id: UUID) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 지우지 않음
    }

    func setlist(showID: UUID) async throws -> [SongSummary] {
        try? await Task.sleep(for: .milliseconds(500))
        return []   // 목데이터: 셋리스트 비어 있음
    }

    func reorder(showID: UUID, songIDs: [String]) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 저장하지 않음
    }

    func moveSong(songID: String, toShowID: UUID) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 옮기지 않음
    }

    func deleteSong(songID: String) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 지우지 않음
    }
}
