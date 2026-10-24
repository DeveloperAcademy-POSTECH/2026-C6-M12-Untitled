//
//  TrackState.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

struct TrackState: Equatable, Identifiable {
    var id: SessionID
    var volume: Float
    var isMuted: Bool
    var activePatchIDs: Set<UUID>
}
