//
//  PlayerDestination.swift
//  Syncy
//
//  Created by anna on 10/22/26.
//

import ComposableArchitecture

extension PlayerFeature {
    @Reducer
    enum Destination {
        case alert(AlertState<PlayerFeature.Action.Alert>)
    }
}
extension PlayerFeature.Destination.State: Equatable {}
extension PlayerFeature.Destination.Action: Sendable {}
