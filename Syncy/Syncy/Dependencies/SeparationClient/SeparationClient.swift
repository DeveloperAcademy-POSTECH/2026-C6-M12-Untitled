//
//  SeparationClient.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct SeparationClient {
    var health: (_ baseURL: URL) async -> Bool = { _ in false }
    var upload: (_ file: URL, _ baseURL: URL) async throws -> String
    var status: (_ jobID: String, _ baseURL: URL) async throws -> JobStatus
    var downloadStem: (_ jobID: String, _ stem: SessionID, _ baseURL: URL) async throws -> URL
}

// liveValue는 Service에 일을 넘기기만 한다.
extension SeparationClient: DependencyKey {
    static let liveValue: SeparationClient = {
        let service = SeparationService()
        return Self(
            health: { baseURL in
                await service.health(baseURL: baseURL)
            },
            upload: { file, baseURL in
                try await service.upload(file: file, baseURL: baseURL)
            },
            status: { jobID, baseURL in
                try await service.status(jobID: jobID, baseURL: baseURL)
            },
            downloadStem: { jobID, stem, baseURL in
                try await service.downloadStem(jobID: jobID, stem: stem, baseURL: baseURL)
            }
        )
    }()
}

extension DependencyValues {
    var separationClient: SeparationClient {
        get { self[SeparationClient.self] }
        set { self[SeparationClient.self] = newValue }
    }
}
