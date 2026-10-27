//
//  TodoItem.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

struct TodoItem: Equatable, Identifiable {
    var songID: String
    var pinID: UUID
    var kind: TodoKind
    var title: String

    var id: UUID { pinID }
}

enum TodoKind: Equatable {
    case talk
    case practice
}
