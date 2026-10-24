//
//  SyncStatus.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case failed(reason: String)
}
