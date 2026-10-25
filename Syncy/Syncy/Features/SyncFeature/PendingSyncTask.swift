//
//  PendingSyncTask.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

/// 아직 서버에 못 보낸 일. 오프라인이면 대기열에 남는다.
enum PendingSyncTask: Equatable {
    case operation(SyncOp)
    case audioUpload(patchID: UUID, fileURL: URL)
}
