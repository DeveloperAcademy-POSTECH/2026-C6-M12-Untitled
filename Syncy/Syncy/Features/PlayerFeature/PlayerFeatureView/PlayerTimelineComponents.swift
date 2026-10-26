//
//  PlayerTimelineComponents.swift
//  Syncy
//
//  Created by anna on 10/27/26.
//

import SwiftUI

struct TrackRangeOverlay: View {
    enum Kind {
        case selection
        case loop
        case recording
    }

    let kind: Kind

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(fillColor)
            .strokeBorder(borderColor, lineWidth: borderWidth)
            .compositingGroup()
            .opacity(kind == .recording ? 0.35 : 1)
            .allowsHitTesting(false)
    }

    private var fillColor: Color {
        switch kind {
        case .selection: Color("AlphaStarLight7")
        case .loop: Color("AlphaStatusWarning10")
        case .recording: Color("StatusDanger")
        }
    }

    private var borderColor: Color {
        switch kind {
        case .selection: Color("Gray600")
        case .loop: Color("StatusWarning")
        case .recording: Color("StatusDanger")
        }
    }

    private var borderWidth: CGFloat {
        switch kind {
        case .selection: 1
        case .loop: 2
        case .recording: 1.5
        }
    }
}

struct MeasureFlagView: View {
    let count: Int

    var body: some View {
        HStack(alignment: .top, spacing: 1) {
            Image("MeasureFlag")
                .renderingMode(.original)
                .frame(width: 12, height: 13)

            Text(count.formatted())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color("Gray100"))
        }
        .frame(minWidth: 20, alignment: .leading)
        .frame(height: 13, alignment: .top)
    }
}

struct FeedbackMarkerView: View {
    let title: String
    let maxWidth: CGFloat
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 3) {
                Image("FeedbackMarkerDot")
                    .renderingMode(.original)
                    .frame(width: 6, height: 6)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color("Gray100"))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: 14)
            }
            .padding(.horizontal, 5)
            .frame(height: 16)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .fixedSize(horizontal: true, vertical: false)
            .clipped()
            .background(Color("Surface1"), in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color("Gray600"), lineWidth: 1)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
