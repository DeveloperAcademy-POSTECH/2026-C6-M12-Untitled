//
//  Color+.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import SwiftUI

extension Color {
    init(hexCode: UInt) {
        self.init(
            red: Double((hexCode >> 16) & 0xFF) / 255,
            green: Double((hexCode >> 8) & 0xFF) / 255,
            blue: Double(hexCode & 0xFF) / 255
        )
    }

    static let accentsBlue = Color(red: 0, green: 0.53, blue: 1)
}
