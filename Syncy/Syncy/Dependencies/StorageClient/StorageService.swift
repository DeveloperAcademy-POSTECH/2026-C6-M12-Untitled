//
//  StorageService.swift
//  Syncy
//
//  Created by moo on 10/22/26.
//

import Foundation

// 핀, 패치, 녹음 파일을 저장하는 곳. StorageClient의 liveValue가 이걸 부름.
// 일단 전부 목데이터로
struct StorageService: Sendable {
    func loadFeedback(songID: String) async throws -> [FeedbackItem] {
        try? await Task.sleep(for: .milliseconds(500))
        return []   // 목데이터: 저장된 핀 없음
    }
    
    func saveFeedback(songID: String, items: [FeedbackItem]) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 저장하지 않음
    }
    
    func loadPatches(songID: String) async throws -> [Patch] {
        try? await Task.sleep(for: .milliseconds(500))
        return []   // 목데이터: 저장된 패치 없음
    }
    
    func savePatches(songID: String, patches: [Patch]) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 저장하지 않음
    }
    
    func savePatchFile(tempFile: Data, patchID: UUID, songID: String) async throws -> URL {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 파일을 옮기지 않고 위치만 돌려줌
        return patchFileURL(patchID: patchID, songID: songID)
    }
    
    func patchFileURL(patchID: UUID, songID: String) -> URL {
        // 목데이터: 실제 저장 위치 미정
        URL(fileURLWithPath: "/목데이터/\(songID)/\(patchID).mp3")
    }
}
