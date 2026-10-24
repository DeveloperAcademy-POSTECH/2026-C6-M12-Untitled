//
//  SeparationService.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

/// 분리 서버와 실제로 일하는 곳. SeparationClient의 liveValue가 이걸 부른다.
struct SeparationService: Sendable {

    func health(baseURL: URL) async -> Bool {
        try? await Task.sleep(for: .milliseconds(500))
        return true
    }

    func upload(file: URL, baseURL: URL) async throws -> String {
        try? await Task.sleep(for: .milliseconds(500))
        return "2"
    }

    func status(jobID: String, baseURL: URL) async throws -> JobStatus {
        try? await Task.sleep(for: .milliseconds(500))
        return JobStatus(
            state: .done,
            stems: [.vocals, .drums, .bass, .guitar, .piano]
        )
    }

    func downloadStem(jobID: String, stem: SessionID, baseURL: URL) async throws -> URL {
        try? await Task.sleep(for: .milliseconds(500))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(jobID)_\(stem.rawValue).mp3")
        FileManager.default.createFile(atPath: tempURL.path, contents: Data())
        return tempURL
    }
}
