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
    var health: (_ baseURL: URL) async throws -> Bool
    var upload: (_ file: Data, _ baseURL: URL) async throws -> String
    var status: (_ jobID: String, _ baseURL: URL) async throws -> JobStatus
    var downloadStem: (_ jobID: String, _ stem: SessionID) async throws -> Data
}

// liveValue는 Service에 일을 넘기기만 한다.
extension SeparationClient: DependencyKey {
    static let liveValue: SeparationClient = {
        let service = SeparationService()
        return Self(
            health: { baseURL in
                try await service.health(baseURL: baseURL)
            },
            upload: { file, baseURL in
                try await service.upload(file: file, baseURL: baseURL)
            },
            status: { jobID, baseURL in
                try await service.status(jobID: jobID, baseURL: baseURL)
            },
            downloadStem: { jobID, stem in
                try await service.downloadStem(jobID: jobID, stem: stem)
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
