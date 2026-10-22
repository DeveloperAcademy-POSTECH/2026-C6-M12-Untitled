//
//  Duration+.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

extension Duration {
    var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
