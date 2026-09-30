import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import ScoreDetectCore

/// SwiftUI can silently drop all but one of several `.fileImporter` modifiers stacked
/// on the same view, so PDF and audio import share a single `.fileImporter` gated by
/// this instead of each getting its own presentation flag.
private enum ImporterKind {
    case pdf
    case audio
}

struct ContentView: View {
    @State private var document: PDFDocument?
    @State private var fileName: String = ""
    @State private var pageIndex: Int = 0
    @State private var parameters = DetectionParameters.default
    @State private var detectedScore: DetectedScore?
    @State private var pageImage: CGImage?
    @State private var selectedMeasureID: Int?
    @State private var isFileImporterPresented = false
    @State private var importerKind: ImporterKind = .pdf
    @State private var isExporterPresented = false
    @State private var exportDocument: JSONFileDocument?
    @State private var statusMessage: String = "악보 PDF를 열어주세요"
    @State private var isSettingsSheetPresented = false
    @State private var isFeedbackListPresented = false
    @State private var isCreatingFeedback = false
    @State private var editingNote: FeedbackNote?

    @State private var isSelectionMode = false
    @State private var selectionRange: ClosedRange<Int>?
    @State private var feedbackNotes: [FeedbackNote] = []

    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var syncSettings = AudioSyncSettings()

    private var currentPage: DetectedPage? {
        detectedScore?.pages.first { $0.pageIndex == pageIndex }
    }

    private var currentPageFeedbackCount: Int {
        feedbackNotes.filter { $0.pageIndex == pageIndex }.count
    }

    /// The measure the audio is currently inside of (and which even beat-slice of
    /// it), if that measure happens to be on the page being displayed right now --
    /// computed from AudioSyncSettings' constant-tempo formula plus an even
    /// beats-per-measure split, not from any real rhythm detection (see
    /// AudioSyncSettings.measureAndBeat's doc comment for why).
    private var highlightedLocation: (measureID: Int, beatIndex: Int)? {
        guard audioPlayer.hasAudio, let detectedScore else { return nil }
        let ordered = detectedScore.orderedMeasures
        guard let location = syncSettings.measureAndBeat(atTime: audioPlayer.currentTime, in: ordered) else {
            return nil
        }
        guard let match = ordered.first(where: { $0.globalIndex == location.globalIndex }), match.pageIndex == pageIndex else {
            return nil
        }
        return (match.measure.id, location.beatIndex)
    }

    private var highlightedMeasureID: Int? { highlightedLocation?.measureID }
    private var highlightedBeatIndex: Int? { highlightedLocation?.beatIndex }

    private var currentMeasureLabel: String? {
        guard let highlightedMeasureID, let measure = currentPage?.measures.first(where: { $0.id == highlightedMeasureID }) else {
            return nil
        }
        var label = "재생 중 S\(measure.systemIndex + 1)-M\(measure.indexInSystem + 1)"
        if let highlightedBeatIndex {
            label += " · \(highlightedBeatIndex + 1)박"
        }
        return label
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                actionBar
                scoreCanvas
                AudioSyncPanel(
                    player: audioPlayer,
                    syncSettings: $syncSettings,
                    onImportTapped: {
                        importerKind = .audio
                        isFileImporterPresented = true
                    },
                    currentMeasureLabel: currentMeasureLabel
                )
            }
            .navigationTitle(fileName.isEmpty ? "악보 인식" : fileName)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        goToPage(pageIndex - 1)
                    } label: {
                        Label("이전 페이지", systemImage: "chevron.left")
                    }
                    .disabled(document == nil || pageIndex <= 0)

                    Spacer()

                    if let document {
                        Text("페이지 \(pageIndex + 1) / \(document.pageCount)")
                            .font(.subheadline.weight(.medium))
                    } else {
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        goToPage(pageIndex + 1)
                    } label: {
                        Label("다음 페이지", systemImage: "chevron.right")
                    }
                    .disabled(document == nil || (document.map { pageIndex >= $0.pageCount - 1 } ?? true))
                }
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: importerKind == .pdf ? [.pdf] : [.audio],
            onCompletion: { result in
                switch importerKind {
                case .pdf: handleImport(result)
                case .audio: handleAudioImport(result)
                }
            }
        )
        .fileExporter(
            isPresented: $isExporterPresented,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFileName()
        ) { _ in }
        .sheet(isPresented: $isSettingsSheetPresented) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let currentPage {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("마지막 인식 결과")
                                    .font(.caption.weight(.semibold))
                                Text(calibrationSummary(for: currentPage))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                        DetectionControlsView(parameters: $parameters, onReanalyze: reanalyzeCurrentPage)
                    }
                    .padding()
                }
                .navigationTitle("인식 설정")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("닫기") { isSettingsSheetPresented = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isFeedbackListPresented) {
            feedbackListSheet
        }
        .sheet(isPresented: $isCreatingFeedback) {
            if let selectionRange {
                FeedbackSheet(
                    pageIndex: pageIndex,
                    rangeStart: selectionRange.lowerBound,
                    rangeEnd: selectionRange.upperBound,
                    existingNote: nil,
                    onSave: { note in
                        feedbackNotes.append(note)
                        self.selectionRange = nil
                        isSelectionMode = false
                    },
                    onDelete: nil
                )
            }
        }
        .sheet(item: $editingNote) { note in
            FeedbackSheet(
                pageIndex: note.pageIndex,
                rangeStart: note.startMeasureID,
                rangeEnd: note.endMeasureID,
                existingNote: note,
                onSave: { updated in
                    if let idx = feedbackNotes.firstIndex(where: { $0.id == updated.id }) {
                        feedbackNotes[idx] = updated
                    }
                },
                onDelete: {
                    feedbackNotes.removeAll { $0.id == note.id }
                }
            )
        }
        .onChange(of: isSelectionMode) { _, isOn in
            if !isOn { selectionRange = nil }
        }
    }

    // A custom labeled button row, rather than the system .toolbar: SwiftUI collapses
    // ToolbarItem labels to icon-only on iPad's regular-width nav bar even with
    // .labelStyle(.titleAndIcon), which is exactly the "I can't tell what this button
    // does" problem this screen used to have. This row guarantees icon + text together.
    private var actionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                actionPill(icon: "doc.badge.plus", title: "악보 열기") {
                    importerKind = .pdf
                    isFileImporterPresented = true
                }
                actionPill(icon: "highlighter", title: "구간 선택", isOn: isSelectionMode, isDisabled: detectedScore == nil) {
                    isSelectionMode.toggle()
                }
                actionPill(icon: "text.bubble", title: "피드백 \(currentPageFeedbackCount)개", isDisabled: detectedScore == nil) {
                    isFeedbackListPresented = true
                }
                actionPill(icon: "slider.horizontal.3", title: "인식 설정") {
                    isSettingsSheetPresented = true
                }
                actionPill(icon: "square.and.arrow.up", title: "내보내기", isDisabled: detectedScore == nil) {
                    exportJSON()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func actionPill(icon: String, title: String, isOn: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isOn ? Color.accentColor : Color.gray.opacity(0.15), in: Capsule())
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
    }

    @ViewBuilder
    private var scoreCanvas: some View {
        ZStack {
            if let pageImage {
                ScorePageOverlayView(
                    cgImage: pageImage,
                    page: currentPage,
                    selectedMeasureID: $selectedMeasureID,
                    isSelectionMode: isSelectionMode,
                    selectionRange: $selectionRange,
                    highlightedMeasureID: highlightedMeasureID,
                    highlightedBeatIndex: highlightedBeatIndex,
                    beatsPerMeasure: max(1, Int(syncSettings.beatsPerMeasure.rounded(.down))),
                    onMeasureTapped: handleMeasureTapped
                )
            } else {
                ContentUnavailableView {
                    Label(statusMessage, systemImage: "doc.text.magnifyingglass")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if let currentPage {
                Text("System \(currentPage.systems.count)개 · 마디 \(currentPage.measures.count)개")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
        }
        .overlay(alignment: .bottom) {
            if isSelectionMode, let selectionRange {
                selectionActionBar(for: selectionRange)
            } else if isSelectionMode {
                Text("피드백을 남길 마디를 탭하세요")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 12)
            }
        }
    }

    private func selectionActionBar(for range: ClosedRange<Int>) -> some View {
        HStack {
            Text("마디 \(range.lowerBound + 1)~\(range.upperBound + 1) 선택됨")
                .font(.footnote.weight(.medium))
            Spacer()
            Button("선택 해제") { selectionRange = nil }
                .font(.footnote)
            Button("피드백 작성") { isCreatingFeedback = true }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private var feedbackListSheet: some View {
        NavigationStack {
            List {
                let notes = feedbackNotes
                    .filter { $0.pageIndex == pageIndex }
                    .sorted { $0.startMeasureID < $1.startMeasureID }
                if notes.isEmpty {
                    Text("이 페이지에 작성된 피드백이 없어요. 상단의 \"구간 선택\"을 켠 뒤 마디를 탭해 구간을 고르고 피드백을 남겨보세요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(notes) { note in
                        Button {
                            editingNote = note
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("마디 \(note.startMeasureID + 1)~\(note.endMeasureID + 1)")
                                    .font(.subheadline.weight(.semibold))
                                Text(note.text)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("피드백 목록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { isFeedbackListPresented = false }
                }
            }
        }
    }

    /// `beatIndex` is which even beat-slice of the tapped measure the tap actually
    /// landed on (left-to-right across the measure box) -- see
    /// `AudioSyncSettings.startTime(forGlobalMeasureIndex:beatIndex:in:)`'s doc
    /// comment for the even-division assumption behind it.
    private func handleMeasureTapped(_ measure: DetectedMeasure, beatIndex: Int) {
        guard audioPlayer.hasAudio, let detectedScore else { return }
        let ordered = detectedScore.orderedMeasures
        guard let match = ordered.first(where: { $0.pageIndex == pageIndex && $0.measure.id == measure.id }) else { return }
        guard let time = syncSettings.startTime(forGlobalMeasureIndex: match.globalIndex, beatIndex: beatIndex, in: ordered) else { return }
        audioPlayer.seekAndPlay(to: time)
    }

    private func handleAudioImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            audioPlayer.load(url: url)
        case .failure(let error):
            audioPlayer.loadErrorMessage = "오디오를 여는 중 오류: \(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }

            guard let doc = PDFDocument(url: url) else {
                statusMessage = "PDF를 열 수 없어요 (손상되었거나 지원하지 않는 형식일 수 있어요)"
                return
            }
            guard !doc.isLocked else {
                // A locked PDFDocument still "opens" (non-nil) but every page renders
                // blank until unlocked, so without this check the user would just see
                // "System 0개, 마디 0개" with no explanation of why.
                statusMessage = "암호로 보호된 PDF예요. 잠금을 해제한 파일로 다시 시도해주세요"
                document = nil
                pageImage = nil
                detectedScore = nil
                return
            }
            guard doc.pageCount > 0 else {
                statusMessage = "이 PDF에는 페이지가 없어요"
                document = nil
                pageImage = nil
                detectedScore = nil
                return
            }
            document = doc
            fileName = url.lastPathComponent
            pageIndex = 0
            detectedScore = nil
            selectedMeasureID = nil
            selectionRange = nil
            isSelectionMode = false
            feedbackNotes = []
            // A previously-loaded recording belongs to whatever score it was synced
            // against; carrying it over to an unrelated new PDF would silently mis-sync
            // (see AudioPlayerManager.unload's doc comment).
            audioPlayer.unload()
            reanalyzeCurrentPage()

        case .failure(let error):
            statusMessage = "가져오기 실패: \(error.localizedDescription)"
        }
    }

    private func goToPage(_ newIndex: Int) {
        guard let document, newIndex >= 0, newIndex < document.pageCount else { return }
        pageIndex = newIndex
        selectedMeasureID = nil
        selectionRange = nil
        reanalyzeCurrentPage()
    }

    private func reanalyzeCurrentPage() {
        guard let document, let page = document.page(at: pageIndex) else {
            statusMessage = "페이지를 찾을 수 없어요"
            return
        }

        guard let rasterized = PDFPageRasterizer.rasterize(page: page, scale: parameters.renderScale) else {
            statusMessage = "페이지를 이미지로 변환하지 못했어요"
            return
        }
        pageImage = rasterized.image

        guard let detected = ScoreDetector.detectPage(page, pageIndex: pageIndex, parameters: parameters) else {
            statusMessage = "인식에 실패했어요"
            return
        }

        var pages = detectedScore?.pages.filter { $0.pageIndex != pageIndex } ?? []
        pages.append(detected)
        pages.sort { $0.pageIndex < $1.pageIndex }
        detectedScore = DetectedScore(sourceFileName: fileName, parameters: parameters, pages: pages)

        if detected.systems.isEmpty {
            statusMessage = "이 페이지에서 오선을 찾지 못했어요 (빈 페이지이거나, 인식 설정 조정이 필요할 수 있어요)"
        } else {
            statusMessage = "System \(detected.systems.count)개, 마디 \(detected.measures.count)개 인식"
        }
    }

    /// One-line readout of what auto-calibration/skew-correction (if enabled) actually
    /// did for this page, so the user can sanity-check the numbers behind the detected
    /// boxes rather than treating the pipeline as a black box.
    private func calibrationSummary(for page: DetectedPage) -> String {
        var parts: [String] = ["임계값 \(page.usedDarkThreshold)"]
        if let thickness = page.estimatedStaffLineThicknessPx {
            parts.append("오선 두께 ≈\(String(format: "%.1f", thickness))px")
        }
        if let space = page.estimatedStaffSpacePx {
            parts.append("오선 간격 ≈\(String(format: "%.1f", space))px")
        }
        if let skew = page.appliedSkewAngleDegrees, abs(skew) > 0.01 {
            parts.append("기울기 보정 \(String(format: "%.1f", skew))°")
        }
        if !parameters.useAutoCalibration {
            parts.append("(수동)")
        }
        return parts.joined(separator: " · ")
    }

    private func exportFileName() -> String {
        let base = (fileName as NSString).deletingPathExtension
        return base.isEmpty ? "detected_score" : "\(base)_detected"
    }

    private func exportJSON() {
        guard let detectedScore else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(detectedScore) else {
            statusMessage = "JSON 인코딩 실패"
            return
        }
        exportDocument = JSONFileDocument(data: data)
        isExporterPresented = true
    }
}
