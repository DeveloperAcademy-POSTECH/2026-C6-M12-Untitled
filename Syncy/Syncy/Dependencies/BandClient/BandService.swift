//
//  BandService.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

// 밴드 만들기 · 합류 · 멤버를 다루는 곳. BandClient의 liveValue가 이걸 부름.
// 일단 전부 목데이터로
struct BandService: Sendable {
    func create(draft: BandDraft) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 만들지 않음
    }

    func find(inviteCode: String) async throws -> Band? {
        try? await Task.sleep(for: .milliseconds(500))
        return nil   // 목데이터: 찾은 밴드 없음
    }

    func join(bandID: UUID, part: Part) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 합류하지 않음
    }

    func members(bandID: UUID) async throws -> [BandMember] {
        try? await Task.sleep(for: .milliseconds(500))
        return []   // 목데이터: 멤버 없음
    }

    func leave(bandID: UUID) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 나가지 않음
    }

    func addPart(name: String) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 추가하지 않음
    }
}
