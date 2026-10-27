//
//  AuthClient.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct AuthClient {
    var currentUser: () async -> Person?
    // 로그인 · 가입 반환 타입 미정
    var signInWithApple: () async throws -> Void
    var signInWithEmail: (_ email: String, _ password: String) async throws -> Void
    var signUp: (_ email: String, _ password: String) async throws -> Void
    var signOut: () async throws -> Void
    var reauthenticate: () async throws -> Void
    var deleteAccount: () async throws -> Void
    // events는 이벤트 타입 미정
}

// liveValue는 Service에 일을 넘기기만 한다.
extension AuthClient: DependencyKey {
    static let liveValue: AuthClient = {
        let service = AuthService()
        return Self(
            currentUser: {
                await service.currentUser()
            },
            signInWithApple: {
                try await service.signInWithApple()
            },
            signInWithEmail: { email, password in
                try await service.signInWithEmail(email: email, password: password)
            },
            signUp: { email, password in
                try await service.signUp(email: email, password: password)
            },
            signOut: {
                try await service.signOut()
            },
            reauthenticate: {
                try await service.reauthenticate()
            },
            deleteAccount: {
                try await service.deleteAccount()
            }
        )
    }()

    // 목데이터 Service라서 previewValue는 liveValue와 같음. 진짜 로그인이 구현되면 분리
    static let previewValue = liveValue
    static let testValue = Self()
}

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
