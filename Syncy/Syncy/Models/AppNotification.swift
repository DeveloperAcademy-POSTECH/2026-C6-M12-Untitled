//
//  AppNotification.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

struct AppNotification: Equatable, Identifiable {
    var id: UUID
    var kind: Kind
    var title: String
    var body: String
    var songID: String?
    var pinID: UUID?
    var createdAt: Date
    var isRead: Bool

    enum Kind: Equatable, Hashable {
        case feedback
        case recording
        case showSong
        case dDay
    }
}
