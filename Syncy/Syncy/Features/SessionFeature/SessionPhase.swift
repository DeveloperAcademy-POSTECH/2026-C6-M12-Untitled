//
//  SessionPhase.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

extension SessionFeature {
    enum SessionPhase: Equatable {
        case idle, uploading
        case uploadFailed(reason: String)
        case separating
        case separationFailed(reason: String)
        case downloading
        case downloadFailed(reason: String)
        case ready
    }
}
