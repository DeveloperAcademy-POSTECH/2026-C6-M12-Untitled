//
//  TrackHeaderView.swift
//  Syncy
//
//  Created by anna on 10/27/26.
//

import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard !samples.isEmpty, size.width > 0 else { return }
            let columns = max(1, Int(size.width / 4))
            var bars = Path()
            for column in 0..<columns {
                let start = min(samples.count - 1, column * samples.count / columns)
                let end = min(samples.count, max(start + 1, (column + 1) * samples.count / columns))
                let amplitude = CGFloat(samples[start..<end].max() ?? 0)
                let height = max(1, min(1, max(0, amplitude)) * size.height)
                bars.addRect(CGRect(
                    x: CGFloat(column) * 4 + 1, y: (size.height - height) / 2,
                    width: 2, height: height
                ))
            }
            context.fill(bars, with: .color(color))
        }
        .allowsHitTesting(false)
    }
}

extension SessionID {
    var playerTitle: String {
        switch self {
        case .vocals: "Vocal"
        case .piano: "Keyboard"
        case .guitar: "Guitar"
        case .drums: "Drum"
        case .bass: "Bass"
        }
    }

    var playerOrder: Int {
        switch self {
        case .vocals: 0
        case .piano: 1
        case .guitar: 2
        case .drums: 3
        case .bass: 4
        }
    }

    var waveformColor: Color {
        switch self {
        case .vocals: Color("WaveformVocal")
        case .piano: Color("WaveformKeyboard")
        case .guitar: Color("WaveformGuitar")
        case .drums: Color("WaveformDrum")
        case .bass: Color("WaveformBass")
        }
    }
}
