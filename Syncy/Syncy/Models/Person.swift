//
//  Person.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import ComposableArchitecture
import Foundation

struct Person: Equatable{
    var id: UUID
    var name: String
    var part: SessionID
}
