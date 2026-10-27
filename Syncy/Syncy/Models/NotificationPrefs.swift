//
//  NotificationPrefs.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

struct NotificationPrefs: Equatable {
    var kinds: Set<AppNotification.Kind> = []
    // quietHours(시작 · 끝), dDay(D-7 · D-1)는 타입 미정
}
