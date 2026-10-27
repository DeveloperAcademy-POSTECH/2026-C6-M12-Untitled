//
//  TrackHeaderView.swift
//  Syncy
//
//  Created by anna on 10/27/26.
//

import SwiftUI

struct TrackHeaderView: View {
    let trackName: String
    // TODO: 멤버 데이터 연결 시 필수 이름과 선택적 프로필 이미지를 전달받는다.
    // let memberName: String
    // var profileImage: Image? = nil
    let isMuted: Bool
    let isSolo: Bool
    @Binding var volume: Float
    let onMuteTapped: () -> Void
    let onSoloTapped: () -> Void

    var body: some View {
        
        VStack(alignment: .leading, spacing: 6.5) {
            HStack(spacing: 10) {
                // TrackProfileView(name: memberName, image: profileImage)
                // 프로필 연결 전에도 트랙 이름의 배치 위치는 유지한다.
                Color.clear.frame(width: 32, height: 32)

                Text(trackName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color("Gray100"))
                    .lineLimit(1)
                    .frame(height: 20)
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    TrackControlButton(kind: .mute, isActive: isMuted) {
                        onMuteTapped()
                    }
                    TrackControlButton(kind: .solo, isActive: isSolo) {
                        onSoloTapped()
                    }
                }

                TrackVolumeSlider(volume: $volume)
                    .offset(y: -0.5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 38)
        .frame(width: PlayerLayout.headerWidth, height: PlayerLayout.rowHeight, alignment: .topLeading)
    }
}

struct TrackControlButton: View {
    
    enum Kind: String {
        case mute = "M"
        case solo = "S"
    }

    let kind: Kind
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        
        Button {
            action()
        } label: {
            Text(kind.rawValue)
                .font(.callout.weight(.medium))
                .foregroundStyle(isActive ? .black : Color("Gray100"))
                .frame(width: 44, height: 33)
                .background(
                    isActive ? Color("Gray100") : Color("Surface3"),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .padding(.vertical, 5.5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct TrackVolumeSlider: View {
    @Binding var volume: Float
    @GestureState private var dragStartVolume: CGFloat? = nil

    private let width: CGFloat = 108
    private let thumbWidth: CGFloat = 38

    var body: some View {
        let travel = width - thumbWidth
        let displayedVolume = CGFloat(min(max(volume, 0), 1))

        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color("Surface3"))
                .overlay {
                    Capsule().strokeBorder(Color("Gray600"), lineWidth: 1)
                }
                .frame(width: travel, height: 6)
                .offset(x: thumbWidth / 2)

            Capsule()
                .fill(Color("Surface3"))
                .overlay {
                    Capsule().strokeBorder(Color("Gray600"), lineWidth: 1)
                }
                .frame(width: thumbWidth, height: 24)
                .offset(x: travel * displayedVolume)
        }
        .frame(width: width, height: 44, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($dragStartVolume) { value, startVolume, _ in
                    guard startVolume == nil else { return }

                    let thumbStart = travel * displayedVolume
                    let startedOnThumb = (thumbStart...(thumbStart + thumbWidth))
                        .contains(value.startLocation.x)
                    let tappedVolume = (value.startLocation.x - thumbWidth / 2) / travel
                    startVolume = startedOnThumb
                        ? displayedVolume
                        : min(max(tappedVolume, 0), 1)
                }
                .onChanged { value in
                    guard let startVolume = dragStartVolume else { return }
                    let fraction = startVolume + value.translation.width / travel
                    volume = Float(min(max(fraction, 0), 1))
                }
        )
    }
}

struct TrackProfileView: View {
    let name: String
    var image: Image? = nil

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initial)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color("Surface5"))
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(Color("AlphaWhite25"), lineWidth: 1)
        }
    }

    private var initial: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmedName.prefix(1))
    }
}
