import SwiftUI
import ScoreDetectCore

/// Sheet for writing a new feedback note over a just-selected measure range, or for
/// viewing/editing/deleting an existing one (opened from the feedback list). The range
/// itself is fixed by the caller -- this view only edits the note's text.
struct FeedbackSheet: View {
    let pageIndex: Int
    let rangeStart: Int
    let rangeEnd: Int
    var existingNote: FeedbackNote?
    let onSave: (FeedbackNote) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("선택한 구간") {
                    Text("마디 \(rangeStart + 1) ~ \(rangeEnd + 1)")
                        .font(.headline)
                }

                Section("피드백 내용") {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                }

                if onDelete != nil {
                    Section {
                        Button("이 피드백 삭제", role: .destructive) {
                            onDelete?()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existingNote == nil ? "피드백 추가" : "피드백 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let note = FeedbackNote(
                            id: existingNote?.id ?? UUID(),
                            pageIndex: pageIndex,
                            startMeasureID: rangeStart,
                            endMeasureID: rangeEnd,
                            text: text,
                            createdAt: existingNote?.createdAt ?? Date()
                        )
                        onSave(note)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                text = existingNote?.text ?? ""
            }
        }
    }
}
