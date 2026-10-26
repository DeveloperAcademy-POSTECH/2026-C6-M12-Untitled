//
//  PlayerIconButton.swift
//  Syncy
//
//  Created by Taeeun on 10/27/26.
//

import SwiftUI

struct PlayerIconButton: View {
    
    enum Kind {
        case record
        case play
        case restart
        case loop
        case metronome
    }
    
    let kind: Kind
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        
        Button {
            action()
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 57, height: 34)
                .background(backgroundColor)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var symbolName: String {
        switch kind {
        case .record: "circle.fill"
        case .play: isActive ? "pause.fill" : "play.fill"
        case .restart: "backward.end.fill"
        case .loop: "repeat"
        case .metronome: "metronome.fill"
        }
    }
    
    private var iconColor: Color {
        if kind == .record {
            return isActive ? .white : Color("StatusDanger")
        }
        return isActive ? .black : Color("Gray100")
    }
    
    private var backgroundColor: Color {
        guard isActive else { return Color("Surface3") }
        return kind == .record ? Color("StatusDanger") : Color("Gray100")
    }
}
