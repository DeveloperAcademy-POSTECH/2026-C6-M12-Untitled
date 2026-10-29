//
//  Song.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//
import Foundation

struct Song: Equatable{
    var id: String
    var tracks: [SongTrack]
    var bpm : Int = 120
    var firstBeatOffset : TimeInterval
}
