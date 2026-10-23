//
//  SeparationService.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

/// 분리 서버와 실제로 일하는 곳. SeparationClient의 liveValue가 이걸 부른다.
struct SeparationService: Sendable {

    func health(baseURL: URL) async throws -> Bool {
        try? await Task.sleep(for: .milliseconds(500))
        return true
    }

    func upload(file: Data, baseURL: URL) async throws -> String {
        try? await Task.sleep(for: .milliseconds(500))
        return "2"
    }

    func status(jobID: String, baseURL: URL) async throws -> JobStatus {
        try? await Task.sleep(for: .milliseconds(500))
        return JobStatus(
            state: .done,
            stems: [.vocal, .drums, .bass, .guitar, .piano]
        )
    }

    func downloadStem(jobID: String, stem: SessionID) async throws -> Data {
        try? await Task.sleep(for: .milliseconds(500))
        return Data()
    }
}
