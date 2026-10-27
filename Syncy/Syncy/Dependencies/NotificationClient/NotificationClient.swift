//
//  NotificationClient.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct NotificationClient {
    // 반환 타입 미정
    var requestAuthorization: () async throws -> Void
    // 인자 token 타입 미정
    var registerDeviceToken: () async throws -> Void
    // 인자 filter 타입 미정
    var list: () async throws -> [AppNotification]
    var markAllRead: () async throws -> Void
    var stream: () async -> AsyncStream<AppNotification> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    var preferences: () async throws -> NotificationPrefs
    var setPreferences: (_ prefs: NotificationPrefs) async throws -> Void
}

// liveValue는 Service에 일을 넘기기만 한다.
extension NotificationClient: DependencyKey {
    static let liveValue: NotificationClient = {
        let service = NotificationService()
        return Self(
            requestAuthorization: {
                try await service.requestAuthorization()
            },
            registerDeviceToken: {
                try await service.registerDeviceToken()
            },
            list: {
                try await service.list()
            },
            markAllRead: {
                try await service.markAllRead()
            },
            stream: {
                service.stream()
            },
            preferences: {
                try await service.preferences()
            },
            setPreferences: { prefs in
                try await service.setPreferences(prefs: prefs)
            }
        )
    }()

    // 목데이터 Service라서 previewValue는 liveValue와 같음. 진짜 알림이 구현되면 분리
    static let previewValue = liveValue
    static let testValue = Self()
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
