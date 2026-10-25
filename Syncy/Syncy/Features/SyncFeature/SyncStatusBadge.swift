//
//  SyncStatusBadge.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import SwiftUI
import ComposableArchitecture

/// 화면 맨 위에 붙는 작은 동기화 상태 표시. 상태를 보여 주고, 실패하면 "다시 시도"를 받는다.
struct SyncStatusBadge: View {
    let store: StoreOf<SyncFeature>

    var body: some View {
        HStack(spacing: 8) {
            icon
            Text(title)

            if store.pendingTasks.count > 0 {
                Text("\(store.pendingTasks.count)개 대기")
                    .foregroundStyle(.secondary)
            }

            if isFailed {
                Button("다시 시도") {
                    store.send(.retryTapped)
                }
                .buttonStyle(.borderless)
            }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    // MARK: - 상태별 모양

    @ViewBuilder
    private var icon: some View {
        switch store.status {
        case .idle:
            Image(systemName: "icloud")
        case .syncing:
            ProgressView()
                .controlSize(.small)
        case .synced:
            Image(systemName: "checkmark.icloud")
        case .failed:
            Image(systemName: "icloud.slash")
        }
    }

    private var title: String {
        switch store.status {
        case .idle: return "대기 중"
        case .syncing: return "보내는 중…"
        case .synced: return "동기화됨"
        case .failed: return "오프라인"
        }
    }

    private var tint: Color {
        switch store.status {
        case .idle: return .secondary
        case .syncing: return .blue
        case .synced: return .green
        case .failed: return .red
        }
    }

    private var isFailed: Bool {
        if case .failed = store.status { return true }
        return false
    }
}
