//
//  SongCacheService.swift
//  Syncy
//

import Foundation

/// 받은 파트 파일을 기기에 보관하는 실제 일꾼. SongCacheClient의 liveValue가 이걸 부른다.
/// 저장 위치: Application Support/songs/{jobID}/{파트}.mp3
struct SongCacheService: Sendable {

    /// 임시 파일을 영구 폴더로 옮기고, 옮긴 위치를 돌려준다.
    func store(tempFile: URL, jobID: String, stem: SessionID) async throws -> URL {
        let fileManager = FileManager.default
        let folder = try songsFolder().appendingPathComponent(jobID, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        let destination = folder.appendingPathComponent("\(stem.rawValue).mp3")
        try? fileManager.removeItem(at: destination)
        try fileManager.moveItem(at: tempFile, to: destination)
        return destination
    }

    // 2차에서 추가: 저장된 곡 전체 크기
    func totalSize() async throws -> Int {
        // 목데이터: 계산 방법 미정
        return 0
    }

    // 2차에서 추가: 저장된 곡 전부 지움
    func removeAll() async throws {
        // 목데이터: 지우는 방법 미정
    }

    private func songsFolder() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("songs", isDirectory: true)
    }
}
