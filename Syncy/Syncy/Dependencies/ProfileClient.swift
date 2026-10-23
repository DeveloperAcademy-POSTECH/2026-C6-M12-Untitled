//
//  ProfileClient.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct ProfileClient {
    var current: () async throws -> Person
    var set: (_ person: Person) async throws -> Void
}

// Conform to DependencyKey to provide a live implementation of
// the interface.
extension ProfileClient: DependencyKey{
    static let liveValue = Self()
}

// Register the dependency within DependencyValues.
extension DependencyValues {
  var profileClient: ProfileClient {
    get { self[ProfileClient.self] }
    set { self[ProfileClient.self] = newValue }
  }
}
