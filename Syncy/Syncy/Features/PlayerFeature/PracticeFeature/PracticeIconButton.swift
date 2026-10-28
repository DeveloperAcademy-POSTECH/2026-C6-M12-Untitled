//
//  PracticeIconButton.swift
//  Syncy
//
//  Created by anna on 10/29/26.
//

import SwiftUI

struct PracticeIconButton: View {
    enum Kind {
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
                .foregroundStyle(isActive ? Color.black : Color("Gray100"))
                .frame(width: 57, height: 34)
                .background(isActive ? Color("Gray100") : Color("Surface3"))
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var symbolName: String {
        switch kind {
        case .loop: "repeat"
        case .metronome: "metronome.fill"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack(spacing: 2) {
            PracticeIconButton(kind: .loop) {}
            PracticeIconButton(kind: .metronome) {}
        }
        HStack(spacing: 2) {
            PracticeIconButton(kind: .loop, isActive: true) {}
            PracticeIconButton(kind: .metronome, isActive: true) {}
        }
    }
    .padding()
    .background(Color("Surface2"))
}
