//
//  NotificationService.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

// 알림 권한 · 목록 · 설정을 다루는 곳. NotificationClient의 liveValue가 이걸 부름.
// 일단 전부 목데이터로
struct NotificationService: Sendable {
    func requestAuthorization() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 권한을 묻지 않음
    }

    func registerDeviceToken() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 등록하지 않음
    }

    func list() async throws -> [AppNotification] {
        try? await Task.sleep(for: .milliseconds(500))
        return []   // 목데이터: 알림 없음
    }

    func markAllRead() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 저장하지 않음
    }

    func stream() -> AsyncStream<AppNotification> {
        // 목데이터: 들어오는 알림 없음
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func preferences() async throws -> NotificationPrefs {
        try? await Task.sleep(for: .milliseconds(500))
        return NotificationPrefs()   // 목데이터: 기본 설정
    }

    func setPreferences(prefs: NotificationPrefs) async throws {
        try? await Task.sleep(for: .milliseconds(500))
        // 목데이터: 실제로 저장하지 않음
    }
}
