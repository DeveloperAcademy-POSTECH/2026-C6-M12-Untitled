//
//  FeedbackComment.swift
//  Syncy
//
//  Created by moo on 10/22/26.
//

import Foundation

struct FeedbackComment: Equatable, Codable {
    var id: UUID
    var author: Person
    var text: String
    var createdAt: Date
    var translations: [String: String]?
}
