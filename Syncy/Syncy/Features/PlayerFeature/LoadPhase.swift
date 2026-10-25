//
//  LoadPhase.swift
//  Syncy
//
//  Created by anna on 10/22/26.
//

enum LoadPhase: Equatable {
    case idle
    case loading
    case ready
    case failed(reason: String)
}
