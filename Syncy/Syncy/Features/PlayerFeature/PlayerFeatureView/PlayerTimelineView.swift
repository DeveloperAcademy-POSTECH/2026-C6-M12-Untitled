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
    let isPlaying: Bool
    let isSeekingAllowed: Bool
    let onSeek: (TimeInterval) async -> Void
    @State private var scrollPosition = ScrollPosition(x: 0)
    @State private var scrollOffset: CGFloat = 0
    @State private var isUserScrolling = false
    @State private var zoomScale: CGFloat = 1
    @State private var zoomStart: (scale: CGFloat, time: TimeInterval, anchorX: CGFloat)?
    @GestureState private var isZooming = false

    private var secondsPerBeat: TimeInterval {
        60 / beatGrid.bpm
    }

    private var basePointsPerSecond: CGFloat {
        return viewportWidth / CGFloat(secondsPerBeat * 4 * 10)
    }

    private var pointsPerSecond: CGFloat {
        basePointsPerSecond * zoomScale
    }

    private var minimumZoomScale: CGFloat {
        min(1, viewportWidth / max(viewportWidth, CGFloat(duration) * basePointsPerSecond))
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
            .onScrollPhaseChange { _, phase in
                switch phase {
                case .tracking, .interacting, .decelerating:
                    isUserScrolling = true
                case .idle, .animating:
                    isUserScrolling = false
                }
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(isZooming)

            PlayerPlayheadView(
                pointsPerSecond: pointsPerSecond,
                duration: duration,
                viewportWidth: viewportWidth,
                scrollOffset: scrollOffset,
                maximumScrollOffset: max(0, contentWidth - viewportWidth),
                isFollowingPlayback: isPlaying && !isUserScrolling && !isZooming,
                isUserInteracting: isUserScrolling || isZooming,
                isSeekingAllowed: isSeekingAllowed && !isZooming,
                onScroll: { offset in scrollPosition.scrollTo(x: offset) },
                onSeek: onSeek
            )
            .padding(.top, 25)
        }
        .frame(height: PlayerLayout.rulerHeight + CGFloat(tracks.count) * PlayerLayout.rowHeight)
        .coordinateSpace(name: "playerTimeline")
        .background(Color("Surface2"))
        .simultaneousGesture(zoomGesture)
        .onChange(of: isZooming) { _, isZooming in
            if !isZooming { zoomStart = nil }
        }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .updating($isZooming) { _, isZooming, _ in
                isZooming = true
            }
            .onChanged { value in
                if zoomStart == nil {
                    let anchorX = min(max(0, value.startLocation.x), viewportWidth)
                    zoomStart = (zoomScale, Double((scrollOffset + anchorX) / pointsPerSecond), anchorX)
                }
                guard let start = zoomStart else { return }
                let scale = min(max(start.scale * value.magnification, minimumZoomScale), 8)
                zoomScale = scale
                let newPointsPerSecond = basePointsPerSecond * scale
                let maximumOffset = max(0, CGFloat(duration) * newPointsPerSecond - viewportWidth)
                let offset = min(max(0, CGFloat(start.time) * newPointsPerSecond - start.anchorX), maximumOffset)
                scrollPosition.scrollTo(x: offset)
            }
    }

    private func seek(at x: CGFloat) {
        guard isSeekingAllowed, !isZooming else { return }
        let target = min(max(0, Double(x / pointsPerSecond)), duration)
        Task { await onSeek(target) }
    }

    private var ruler: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: 25)), with: .color(Color("Surface3")))
            context.fill(Path(CGRect(x: 0, y: 25, width: size.width, height: size.height - 25)), with: .color(.black))
            let subdivision = secondsPerBeat / 4
            let visibleDuration = Double(size.width / pointsPerSecond)
            let ticks = Int(max(0, (visibleDuration - beatGrid.firstBeatOffset) / subdivision))
            let labelFont = Font.system(size: 12, weight: .light)
            let sampleLabel = Text(String(repeating: "8", count: String(ticks / 16 + 1).count))
                .font(labelFont)
            let labelWidth = context.resolve(sampleLabel)
                .measure(in: CGSize(width: CGFloat.infinity, height: 25)).width
            let pointsPerBar = CGFloat(secondsPerBeat * 4) * pointsPerSecond
            var labelInterval = 1
            // 숫자 폭과 여백이 확보되도록 1·2·4·8마디 단위로 표시 간격을 늘린다.
            while CGFloat(labelInterval) * pointsPerBar < labelWidth + 10 {
                labelInterval *= 2
            }
            var measureLines = Path()
            var beatLines = Path()
            for tick in 0...ticks {
                let time = beatGrid.firstBeatOffset + Double(tick) * subdivision
                let x = CGFloat(time) * pointsPerSecond
                guard x >= 0, x <= size.width else { continue }
                if tick.isMultiple(of: 16) {
                    measureLines.move(to: CGPoint(x: x, y: 0))
                    measureLines.addLine(to: CGPoint(x: x, y: size.height))
                    if (tick / 16).isMultiple(of: labelInterval) {
                        context.draw(
                            Text("\(tick / 16 + 1)").font(labelFont).foregroundStyle(Color("Gray100")),
                            at: CGPoint(x: x + 5, y: 12), anchor: .leading
                        )
                    }
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
            seek(at: location.x)
        }
    }

    private func lane(_ track: TrackState) -> some View {
        VStack(spacing: 0) {
            Rectangle()
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
        .contentShape(Rectangle())
        .onTapGesture { location in
            seek(at: location.x)
        }
    }
}

private struct PlayerPlayheadView: View {
    let pointsPerSecond: CGFloat
    let duration: TimeInterval
    let viewportWidth: CGFloat
    let scrollOffset: CGFloat
    let maximumScrollOffset: CGFloat
    let isFollowingPlayback: Bool
    let isUserInteracting: Bool
    let isSeekingAllowed: Bool
    let onScroll: (CGFloat) -> Void
    let onSeek: (TimeInterval) async -> Void
    @Dependency(\.audioClient) private var audioClient
    @Dependency(\.continuousClock) private var clock
    @State private var time: TimeInterval = 0
    @State private var dragLocation: CGFloat?
    @State private var dragStart: (time: TimeInterval, location: CGFloat, scrollOffset: CGFloat)?
    @State private var pendingSeek: TimeInterval?
    @GestureState private var isDragging = false
    @State private var isFollowSuspended = false

    private var displayedTime: TimeInterval {
        guard let dragLocation else { return pendingSeek ?? time }
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
                                guard isSeekingAllowed else { return }
                                if dragStart == nil {
                                    dragStart = (displayedTime, value.startLocation.x, scrollOffset)
                                }
                                dragLocation = value.location.x
                            }
                            .onEnded { value in
                                guard isSeekingAllowed else { return }
                                pendingSeek = seekTime(at: value.location.x)
                            }
                    )
                    .allowsHitTesting(isSeekingAllowed && isVisible)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .onChange(of: isDragging) { _, isDragging in
            if isDragging {
                isFollowSuspended = true
            } else {
                dragLocation = nil
                dragStart = nil
            }
        }
        .onChange(of: isUserInteracting) { _, isUserInteracting in
            if isUserInteracting { isFollowSuspended = true }
        }
        .onChange(of: isFollowingPlayback) { _, isFollowingPlayback in
            if isFollowingPlayback { followPlayback(at: time) }
        }
        .onChange(of: time) { _, time in
            followPlayback(at: time)
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
        .task(id: pendingSeek) {
            guard let target = pendingSeek else { return }
            await onSeek(target)
            guard !Task.isCancelled else { return }
            time = target
            pendingSeek = nil
        }
        .task(id: pendingSeek) {
            // 이동 중 받은 이전 위치는 버리고, 이동이 끝나면 엔진의 현재 위치부터 다시 받는다.
            guard pendingSeek == nil else { return }
            for await time in await audioClient.position() {
                guard !Task.isCancelled else { return }
                guard time.isFinite, time >= 0 else { continue }
                self.time = time
            }
        }
    }

    private func followPlayback(at time: TimeInterval) {
        guard isFollowingPlayback, !isDragging, pendingSeek == nil else { return }
        let x = CGFloat(time) * pointsPerSecond
        // 사용자가 재생선을 화면 밖으로 옮겼다면, 다시 화면에 들어올 때까지 기다린다.
        if isFollowSuspended {
            guard x >= scrollOffset, x <= scrollOffset + viewportWidth else { return }
            isFollowSuspended = false
        }
        // 중앙에 도달한 뒤에는 재생선을 따라 스크롤하고, 반복으로 되돌아간 위치도 보여준다.
        guard x - scrollOffset >= viewportWidth / 2 || x < scrollOffset else { return }
        let offset = min(max(0, x - viewportWidth / 2), maximumScrollOffset)
        if offset != scrollOffset { onScroll(offset) }
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
