//
//  ServerStatus.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

extension SessionFeature {
    enum ServerStatus: Equatable{
        case searching
        case connected(name: String)
        case notFound
    }
}
