//
//  TrackHeaderView.swift
//  Syncy
//
//  Created by anna on 10/27/26.
//

import SwiftUI
import ComposableArchitecture

enum PlayerLayout {
    static let headerWidth: CGFloat = 244
    static let rowHeight: CGFloat = 178
    static let rulerHeight: CGFloat = 52
}

struct PlayerTimelineView: View {
    let tracks: [TrackState]
    let waveforms: [SessionID: WaveformPeaks]
    let waveformErrors: [SessionID: String]
    let beatGrid: BeatGrid
    let duration: TimeInterval
    let viewportWidth: CGFloat
    let isSeekingAllowed: Bool
    let onSeek: (TimeInterval) -> Void
    @State private var scrollPosition = ScrollPosition(x: 0)
    @State private var scrollOffset: CGFloat = 0

    private var secondsPerBeat: TimeInterval {
        60 / beatGrid.bpm
    }

    private var pointsPerSecond: CGFloat {
        return viewportWidth / CGFloat(secondsPerBeat * 4 * 10)
    }

    private var contentWidth: CGFloat {
        max(viewportWidth, CGFloat(max(0, duration)) * pointsPerSecond)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    ruler
                    ForEach(tracks) { track in
                        lane(track)
                    }
                }
                .frame(width: contentWidth)
            }
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                max(0, geometry.contentOffset.x + geometry.contentInsets.leading)
            } action: { _, offset in
                scrollOffset = offset
            }
            .scrollIndicators(.hidden)

            PlayerPlayheadView(
                pointsPerSecond: pointsPerSecond,
                duration: duration,
                viewportWidth: viewportWidth,
                scrollOffset: scrollOffset,
                maximumScrollOffset: max(0, contentWidth - viewportWidth),
                isSeekingAllowed: isSeekingAllowed,
                onScroll: { offset in scrollPosition.scrollTo(x: offset) },
                onSeek: onSeek
            )
            .padding(.top, 25)
        }
        .frame(height: PlayerLayout.rulerHeight + CGFloat(tracks.count) * PlayerLayout.rowHeight)
        .coordinateSpace(name: "playerTimeline")
        .background(Color("Surface2"))
    }

    private var ruler: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: 25)), with: .color(Color("Surface3")))
            context.fill(Path(CGRect(x: 0, y: 25, width: size.width, height: size.height - 25)), with: .color(.black))
            let subdivision = secondsPerBeat / 4
            let visibleDuration = Double(size.width / pointsPerSecond)
            let ticks = Int(max(0, (visibleDuration - beatGrid.firstBeatOffset) / subdivision))
            var measureLines = Path()
            var beatLines = Path()
            for tick in 0...ticks {
                let time = beatGrid.firstBeatOffset + Double(tick) * subdivision
                let x = CGFloat(time) * pointsPerSecond
                guard x >= 0, x <= size.width else { continue }
                if tick.isMultiple(of: 16) {
                    measureLines.move(to: CGPoint(x: x, y: 0))
                    measureLines.addLine(to: CGPoint(x: x, y: size.height))
                    context.draw(
                        Text("\(tick / 16 + 1)").font(.system(size: 12, weight: .light)).foregroundStyle(Color("Gray100")),
                        at: CGPoint(x: x + 5, y: 12), anchor: .leading
                    )
                } else {
                    beatLines.move(to: CGPoint(x: x, y: size.height - (tick.isMultiple(of: 4) ? 14 : 7)))
                    beatLines.addLine(to: CGPoint(x: x, y: size.height))
                }
            }
            context.stroke(measureLines, with: .color(Color("Gray600")), lineWidth: 0.5)
            context.stroke(beatLines, with: .color(Color("Surface3")), lineWidth: 1)
        }
        .frame(height: PlayerLayout.rulerHeight)
        .contentShape(Rectangle())
        .onTapGesture { location in
            onSeek(min(max(0, Double(location.x / pointsPerSecond)), duration))
        }
    }

    private func lane(_ track: TrackState) -> some View {
        VStack(spacing: 0) {
            UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8)
                .fill(Color("Surface3"))
                .frame(height: 16)

            ZStack(alignment: .leading) {
                Color("Surface2")
                if let peaks = waveforms[track.id] {
                    WaveformView(samples: peaks.samples, color: track.id.waveformColor)
                        .frame(width: min(contentWidth, CGFloat(peaks.duration) * pointsPerSecond))
                        .padding(.vertical, 14)
                        .opacity(track.isMuted ? 0.35 : 1)
                } else if let reason = waveformErrors[track.id] {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(Color("Gray100"))
                        .frame(width: viewportWidth)
                } else {
                    ProgressView()
                        .tint(Color("Gray100"))
                        .frame(width: viewportWidth)
                }
            }
        }
        .padding(.vertical, 2)
        .frame(height: PlayerLayout.rowHeight)
    }
}

private struct PlayerPlayheadView: View {
    let pointsPerSecond: CGFloat
    let duration: TimeInterval
    let viewportWidth: CGFloat
    let scrollOffset: CGFloat
    let maximumScrollOffset: CGFloat
    let isSeekingAllowed: Bool
    let onScroll: (CGFloat) -> Void
    let onSeek: (TimeInterval) -> Void
    @Dependency(\.audioClient) private var audioClient
    @Dependency(\.continuousClock) private var clock
    @State private var time: TimeInterval = 0
    @State private var dragLocation: CGFloat?
    @State private var dragStart: (time: TimeInterval, location: CGFloat, scrollOffset: CGFloat)?
    @GestureState private var isDragging = false

    private var displayedTime: TimeInterval {
        guard let dragLocation else { return time }
        return seekTime(at: dragLocation)
    }

    private var playheadX: CGFloat {
        CGFloat(displayedTime) * pointsPerSecond - scrollOffset
    }

    private var isVisible: Bool {
        isDragging || (-3...viewportWidth + 3).contains(playheadX)
    }

    private var visiblePlayheadX: CGFloat {
        min(max(0, playheadX), max(0, viewportWidth - 3))
    }

    private var touchAreaX: CGFloat {
        min(visiblePlayheadX - 22, max(0, viewportWidth - 44))
    }

    private var autoScrollOffset: CGFloat? {
        guard isDragging, isSeekingAllowed, let dragLocation else { return nil }
        let edgeWidth: CGFloat = 44
        let direction: CGFloat
        if dragLocation < edgeWidth {
            direction = -min(1, (edgeWidth - dragLocation) / edgeWidth)
        } else if dragLocation > viewportWidth - edgeWidth {
            direction = min(1, (dragLocation - viewportWidth + edgeWidth) / edgeWidth)
        } else {
            return nil
        }
        let offset = min(max(0, scrollOffset + direction * viewportWidth * 0.8 * 0.016), maximumScrollOffset)
        return offset == scrollOffset ? nil : offset
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color("Gray600"))
                    .frame(width: 2, height: geometry.size.height)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color("Gray600"))
                            .frame(width: 6, height: 34)
                    }
                    .offset(x: visiblePlayheadX - 1)
                    .allowsHitTesting(false)

                Color.clear
                    .frame(width: 44, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .position(x: touchAreaX + 22, y: geometry.size.height / 2)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("playerTimeline"))
                            .updating($isDragging) { _, isDragging, _ in
                                isDragging = true
                            }
                            .onChanged { value in
                                if dragStart == nil {
                                    dragStart = (time, value.startLocation.x, scrollOffset)
                                }
                                dragLocation = value.location.x
                            }
                            .onEnded { value in
                                onSeek(seekTime(at: value.location.x))
                            }
                    )
                    .allowsHitTesting(isSeekingAllowed && isVisible)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .onChange(of: isDragging) { _, isDragging in
            if !isDragging {
                dragLocation = nil
                dragStart = nil
            }
        }
        .task(id: autoScrollOffset) {
            guard let offset = autoScrollOffset else { return }
            do {
                try await clock.sleep(for: .milliseconds(16))
                try Task.checkCancellation()
                onScroll(offset)
            } catch {
                return
            }
        }
        .task {
            for await time in await audioClient.position() {
                guard !Task.isCancelled else { return }
                guard time.isFinite, time >= 0 else { continue }
                self.time = time
            }
        }
    }

    private func seekTime(at location: CGFloat) -> TimeInterval {
        guard let start = dragStart else { return time }
        let x = min(max(0, location), viewportWidth)
        let startX = min(max(0, start.location), viewportWidth)
        // 잡은 지점과 재생선 사이 간격을 유지하고, 자동 스크롤로 이동한 거리도 더한다.
        let distance = x - startX + scrollOffset - start.scrollOffset
        return min(max(0, start.time + Double(distance / pointsPerSecond)), duration)
    }
}
