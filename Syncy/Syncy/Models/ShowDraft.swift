//
//  ShowDraft.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

struct ShowDraft: Equatable {
    var name: String
    var startsAt: Date?
    var venue: String?
    var sessionIDs: [SessionID]
}
