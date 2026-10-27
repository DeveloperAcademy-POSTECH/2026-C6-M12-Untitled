//
//  AuthService.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

// 로그인 · 계정을 다루는 곳. AuthClient의 liveValue가 이걸 부름.
// 일단 전부 목데이터로
struct AuthService: Sendable {
    func currentUser() async -> Person? {
        try? await Task.sleep(for: .milliseconds(500))
        return nil   // 목데이터: 로그인한 사람 없음
    }

    func signInWithApple() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 로그인하지 않음
    }

    func signInWithEmail(email: String, password: String) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 로그인하지 않음
    }

    func signUp(email: String, password: String) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 로그인하지 않음
    }

    func signOut() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 로그아웃하지 않음
    }

    func reauthenticate() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 재인증하지 않음
    }

    func deleteAccount() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 탈퇴하지 않음
    }
}
