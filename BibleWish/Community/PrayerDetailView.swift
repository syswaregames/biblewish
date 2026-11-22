//
//  PrayerDetailView.swift
//
//  One prayer request with the encouragement under it, and a box to add your own (like the
//  website's "Write a word of encouragement…").
//

import SwiftUI

struct PrayerDetailView: View {

    @EnvironmentObject var store: CommunityStore
    @EnvironmentObject var auth: AuthStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var prayer: CommunityPrayer
    @State private var replies: [CommunityReply] = []
    @State private var loadedReplies = false
    @State private var repliesError: String?
    @State private var draft = ""
    @State private var sending = false
    @State private var showSignIn = false
    @State private var reporting: ReportTarget?
    @State private var blockingPrayer = false
    @State private var blockingReply: CommunityReply?
    @State private var deletingPrayer = false
    @State private var answering = false
    @State private var problem: String?
    @FocusState private var focused: Bool

    init(prayer: CommunityPrayer) {
        _prayer = State(initialValue: prayer)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PrayerCard(
                    prayer: prayer,
                    detail: true,
                    onReact: { kind in guarded { prayer = try await store.react(kind, to: prayer) } },
                    onReport: { guarded(then: { reporting = .prayer(prayer) }) },
                    onBlock: { guarded(then: { blockingPrayer = true }) },
                    onDelete: { deletingPrayer = true },
                    onAnswer: { answering = true }
                )

                Text("ENCOURAGEMENT")
                    .font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(palette.gold)
                    .accessibilityAddTraits(.isHeader)

                if !loadedReplies {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                } else if let repliesError {
                    Text(repliesError).font(.subheadline).foregroundStyle(palette.inkMuted)
                } else if replies.isEmpty {
                    Text("No encouragement yet. Be the first.").font(.subheadline).foregroundStyle(palette.inkMuted)
                } else {
                    ForEach(replies) { reply in replyRow(reply) }
                }
            }
            .padding(16)
            .readableWidth(720)
        }
        .scrollDismissesKeyboard(.interactively)
        .themedScreen()
        .navigationTitle("Prayer request")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .task { await loadReplies() }
        .onReceive(store.$prayers) { list in if let fresh = list.first(where: { $0.id == prayer.id }) { prayer = fresh } }
        .sheet(isPresented: $showSignIn) { SignInView() }
        .sheet(item: $reporting) { target in
            ReportSheet(title: target.isReply ? "Report this reply" : "Report this request") { reason, details in
                try await store.report(prayerId: target.prayerId, replyId: target.replyId, reason: reason, details: details)
            }
        }
        .sheet(isPresented: $answering) {
            AnsweredSheet(prayer: prayer) { answered, note in
                try await store.setAnswered(prayer, answered: answered, note: note)
            }
        }
        .alert("Block this member?", isPresented: $blockingPrayer) {
            Button("Block", role: .destructive) { guarded { try await store.block(prayerId: prayer.id); dismiss() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text(blockMessage) }
        .alert("Block this member?", isPresented: Binding(get: { blockingReply != nil }, set: { if !$0 { blockingReply = nil } })) {
            Button("Block", role: .destructive) {
                if let reply = blockingReply { guarded { try await store.block(prayerId: reply.prayerId, replyId: reply.id); await loadReplies() } }
                blockingReply = nil
            }
            Button("Cancel", role: .cancel) { blockingReply = nil }
        } message: { Text(blockMessage) }
        .alert("Delete this request?", isPresented: $deletingPrayer) {
            Button("Delete", role: .destructive) { guarded { try await store.delete(prayer); dismiss() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("It is removed from the wall, with its encouragement. This cannot be undone.") }
        .alert("Something went wrong", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) { problem = nil }
        } message: { Text(problem ?? "") }
    }

    private var blockMessage: String {
        "You will no longer see their requests or replies, and they cannot send you verses. They are not told. You can undo this in Settings \u{2192} Account."
    }

    // MARK: Replies

    private func replyRow(_ reply: CommunityReply) -> some View {
        HStack(alignment: .top, spacing: 10) {
            CommunityAvatar(name: reply.author, path: reply.authorAvatar, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(reply.author).font(.footnote.weight(.semibold)).foregroundStyle(palette.ink)
                    Text(CommunityFormat.flag(reply.authorCountry)).font(.footnote)
                    Text(CommunityFormat.ago(reply.createdAt)).font(.caption).foregroundStyle(palette.inkMuted)
                }
                Text(reply.body).font(.subheadline).foregroundStyle(palette.ink).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Menu {
                if reply.isMine {
                    Button(role: .destructive) { guarded { try await store.deleteReply(reply); replies.removeAll { $0.id == reply.id } } } label: { Label("Delete", systemImage: "trash") }
                } else {
                    Button { guarded(then: { reporting = .reply(reply) }) } label: { Label("Report", systemImage: "flag") }
                    Button(role: .destructive) { guarded(then: { blockingReply = reply }) } label: { Label("Block this member", systemImage: "hand.raised") }
                }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(palette.inkMuted).frame(width: 32, height: 28)
            }
            .accessibilityLabel("More options")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(cornerRadius: 12)
        .accessibilityElement(children: .contain)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(auth.isSignedIn ? "Write a word of encouragement\u{2026}" : "Sign in to encourage", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($focused)
                .disabled(!auth.isSignedIn)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 18).fill(palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.goldLine))
                .onChange(of: draft) { if draft.count > 500 { draft = String(draft.prefix(500)) } }
                .onTapGesture { if !auth.isSignedIn { showSignIn = true } }
            Button { send() } label: {
                Group {
                    if sending { ProgressView() } else { Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)) }
                }
                .frame(width: 36, height: 36)
                .foregroundStyle(canSend ? palette.gold : palette.inkMuted)
            }
            .disabled(!canSend)
            .accessibilityLabel("Send encouragement")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(palette.panel)
        .overlay(alignment: .top) { Rectangle().fill(palette.goldLine).frame(height: 1) }
    }

    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { auth.isSignedIn && trimmedDraft.count >= 2 && !sending }

    private func send() {
        let text = trimmedDraft
        sending = true
        Task {
            defer { sending = false }
            do {
                let reply = try await store.reply(to: prayer.id, body: text)
                replies.append(reply)
                draft = ""
                prayer.replyCount = replies.count
            } catch APIError.unauthorized {
                showSignIn = true
            } catch {
                problem = CommunityStore.message(error)
            }
        }
    }

    private func loadReplies() async {
        do {
            replies = try await store.replies(for: prayer.id)
            repliesError = nil
        } catch {
            repliesError = CommunityStore.message(error)
        }
        loadedReplies = true
    }

    private func guarded(_ work: @escaping () async throws -> Void) {
        guard auth.isSignedIn else { showSignIn = true; return }
        Task {
            do { try await work() }
            catch APIError.unauthorized { showSignIn = true }
            catch { problem = CommunityStore.message(error) }
        }
    }

    private func guarded(then action: () -> Void) {
        guard auth.isSignedIn else { showSignIn = true; return }
        action()
    }
}

/// A prayer opened from a notification: fetched first, then shown.
struct PrayerLoadingView: View {

    let id: Int
    @EnvironmentObject var store: CommunityStore
    @Environment(\.palette) private var palette
    @State private var prayer: CommunityPrayer?
    @State private var failure: String?

    var body: some View {
        Group {
            if let prayer {
                PrayerDetailView(prayer: prayer)
            } else if let failure {
                VStack(spacing: 8) {
                    Text(failure).font(.subheadline).foregroundStyle(palette.inkMuted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .themedScreen()
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).themedScreen()
            }
        }
        .task {
            do { prayer = try await store.prayer(id: id) }
            catch let error as APIError {
                if case .server(let status, _, let message) = error, status == 404 { failure = message } else { failure = CommunityStore.message(error) }
            } catch { failure = CommunityStore.message(error) }
        }
    }
}
