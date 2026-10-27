//
//  BandClient.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct BandClient {
    // create · join 반환 타입 미정
    var create: (_ draft: BandDraft) async throws -> Void
    var find: (_ inviteCode: String) async throws -> Band?
    var join: (_ bandID: UUID, _ part: Part) async throws -> Void
    var members: (_ bandID: UUID) async throws -> [BandMember]
    var leave: (_ bandID: UUID) async throws -> Void
    // addPart 반환 타입 미정 (Part 모델 결정 전)
    var addPart: (_ name: String) async throws -> Void
}

// liveValue는 Service에 일을 넘기기만 한다.
extension BandClient: DependencyKey {
    static let liveValue: BandClient = {
        let service = BandService()
        return Self(
            create: { draft in
                try await service.create(draft: draft)
            },
            find: { inviteCode in
                try await service.find(inviteCode: inviteCode)
            },
            join: { bandID, part in
                try await service.join(bandID: bandID, part: part)
            },
            members: { bandID in
                try await service.members(bandID: bandID)
            },
            leave: { bandID in
                try await service.leave(bandID: bandID)
            },
            addPart: { name in
                try await service.addPart(name: name)
            }
        )
    }()

    // 목데이터 Service라서 previewValue는 liveValue와 같음. 진짜 밴드 저장이 구현되면 분리
    static let previewValue = liveValue
    static let testValue = Self()
}

extension DependencyValues {
    var bandClient: BandClient {
        get { self[BandClient.self] }
        set { self[BandClient.self] = newValue }
    }
}
