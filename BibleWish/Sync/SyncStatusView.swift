//
//  SyncStatusView.swift
//
//  How the last sync went, and a button to run one now.
//

import SwiftUI

struct SyncStatusView: View {

    @EnvironmentObject var sync: SyncEngine
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(failed ? palette.roseInk : palette.ink)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(palette.inkMuted)
                }
            }
            Spacer()
            if sync.status == .syncing {
                ProgressView()
            } else {
                Button("Sync now") {
                    Task { await sync.syncNow() }
                }
                .font(.subheadline)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var failed: Bool {
        if case .failed = sync.status { return true }
        return false
    }

    private var title: String {
        switch sync.status {
        case .syncing: return "Syncing\u{2026}"
        case .failed(let message): return message
        case .idle:
            if let last = sync.lastSynced {
                return "Synced \(last.formatted(.relative(presentation: .named)))"
            }
            return "Not synced yet"
        }
    }

    private var detail: String? {
        sync.pendingCount > 0 ? "\(sync.pendingCount) change\(sync.pendingCount == 1 ? "" : "s") waiting to be sent" : nil
    }
}
