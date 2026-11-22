//
//  PrayerWallView.swift
//
//  The community prayer wall, like biblewish.com/community: newest or "needs prayer" first, a card
//  per request with "I prayed" and a heart, encouragement under each, and a way to report, block or
//  delete. Reading is open; sharing, praying, encouraging and reporting need an account.
//

import SwiftUI

// MARK: - The wall

struct PrayerWallView: View {

    @EnvironmentObject var store: CommunityStore
    @EnvironmentObject var auth: AuthStore
    @Environment(\.palette) private var palette

    @State private var showComposer = false
    @State private var showSignIn = false
    @State private var showGuidelines = false
    @State private var route: CommunityPrayer?
    @State private var reporting: ReportTarget?
    @State private var blocking: CommunityPrayer?
    @State private var deleting: CommunityPrayer?
    @State private var answering: CommunityPrayer?
    @State private var problem: String?
    @State private var toast: ReaderToast?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            sortPicker
            shareCard

            if !store.loadedOnce {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
            } else if let error = store.errorMessage, store.prayers.isEmpty {
                VStack(spacing: 10) {
                    Text(error).font(.subheadline).foregroundStyle(palette.inkMuted).multilineTextAlignment(.center)
                    Button("Try again") { Task { await store.refresh() } }.font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else if store.prayers.isEmpty {
                Text("No prayer requests yet. Be the first to share one.")
                    .font(.subheadline)
                    .foregroundStyle(palette.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                ForEach(store.prayers) { prayer in
                    PrayerCard(
                        prayer: prayer,
                        onOpen: { route = prayer },
                        onReact: { kind in guarded { try await store.react(kind, to: prayer) } },
                        onReport: { guarded(then: { reporting = .prayer(prayer) }) },
                        onBlock: { guarded(then: { blocking = prayer }) },
                        onDelete: { deleting = prayer },
                        onAnswer: { answering = prayer }
                    )
                }
                if store.hasMore {
                    Button { Task { await store.loadMore() } } label: {
                        Text(store.isLoading ? "Loading\u{2026}" : "More requests")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.goldLine))
                            .foregroundStyle(palette.gold)
                    }
                    .disabled(store.isLoading)
                }
            }

            Button { showGuidelines = true } label: {
                Text("Community guidelines").font(.footnote).foregroundStyle(palette.inkMuted).underline()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .task { if !store.loadedOnce { await store.refresh() } }
        .navigationDestination(item: $route) { PrayerDetailView(prayer: $0) }
        .sheet(isPresented: $showComposer) { PrayerComposerView(onPosted: { toast = ReaderToast(message: "Shared with the community \u{1F64F}") }) }
        .sheet(isPresented: $showSignIn) { SignInView() }
        .sheet(isPresented: $showGuidelines) { CommunityGuidelinesView() }
        .sheet(item: $reporting) { target in
            ReportSheet(title: target.isReply ? "Report this reply" : "Report this request") { reason, details in
                try await store.report(prayerId: target.prayerId, replyId: target.replyId, reason: reason, details: details)
                toast = ReaderToast(message: "Thank you. Our moderator will review it.")
            }
        }
        .sheet(item: $answering) { prayer in
            AnsweredSheet(prayer: prayer) { answered, note in
                try await store.setAnswered(prayer, answered: answered, note: note)
            }
        }
        .alert("Block this member?", isPresented: Binding(get: { blocking != nil }, set: { if !$0 { blocking = nil } })) {
            Button("Block", role: .destructive) {
                if let prayer = blocking { guarded { try await store.block(prayerId: prayer.id); toast = ReaderToast(message: "Blocked. You won\u{2019}t see their posts or replies.") } }
                blocking = nil
            }
            Button("Cancel", role: .cancel) { blocking = nil }
        } message: {
            Text("You will no longer see their requests or replies, and they cannot send you verses. They are not told. You can undo this in Settings \u{2192} Account.")
        }
        .alert("Delete this request?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) {
                if let prayer = deleting { guarded { try await store.delete(prayer) } }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("It is removed from the wall, with its encouragement. This cannot be undone.")
        }
        .alert("Something went wrong", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) { problem = nil }
        } message: { Text(problem ?? "") }
        .overlay(alignment: .top) {
            if let toast {
                ReaderToastView(toast: toast) { self.toast = nil }
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast.id) {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        if self.toast == toast { self.toast = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.35), value: toast)
    }

    // MARK: Pieces

    private var sortPicker: some View {
        Picker("Order", selection: $store.sort) {
            ForEach(CommunityStore.Sort.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    /// The composer's front door, like the website's "What can we pray for?" box.
    private var shareCard: some View {
        Button {
            if auth.isSignedIn { showComposer = true } else { showSignIn = true }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "text.bubble").foregroundStyle(palette.gold)
                Text(auth.isSignedIn ? "What can we pray for?" : "Sign in to share a prayer request")
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSoft)
                Spacer()
                Image(systemName: "square.and.pencil").foregroundStyle(palette.gold)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .themedCard(cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(auth.isSignedIn ? "Share a prayer request" : "Sign in to share a prayer request")
    }

    /// Runs `work` if signed in, else offers to sign in; a refused session does the same.
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

/// What a report is about: a post, or one reply under it.
struct ReportTarget: Identifiable {
    let prayerId: Int
    let replyId: Int?
    var id: String { "\(prayerId)-\(replyId ?? 0)" }
    var isReply: Bool { replyId != nil }

    static func prayer(_ prayer: CommunityPrayer) -> ReportTarget { ReportTarget(prayerId: prayer.id, replyId: nil) }
    static func reply(_ reply: CommunityReply) -> ReportTarget { ReportTarget(prayerId: reply.prayerId, replyId: reply.id) }
}

// MARK: - A card

struct PrayerCard: View {

    let prayer: CommunityPrayer
    var detail = false
    var onOpen: () -> Void = {}
    let onReact: (PrayerReaction) -> Void
    let onReport: () -> Void
    let onBlock: () -> Void
    let onDelete: () -> Void
    let onAnswer: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Text(prayer.body)
                .font(.system(.body, design: .serif))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(detail ? nil : 8)

            if prayer.isAnswered { answered }

            HStack(spacing: 8) {
                reactionButton(.praying, title: "I prayed", count: prayer.prayedCount, on: prayer.iPrayed, icon: "hands.sparkles")
                reactionButton(.heart, title: "Love", count: prayer.heartCount, on: prayer.iHearted, icon: prayer.iHearted ? "heart.fill" : "heart")
                Spacer(minLength: 4)
                Button(action: onOpen) {
                    Label("\(prayer.replyCount)", systemImage: "bubble.left")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .foregroundStyle(palette.inkSoft)
                }
                .accessibilityLabel("\(prayer.replyCount) encouragements. Open")
                .disabled(detail)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(cornerRadius: 14)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { if !detail { onOpen() } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            CommunityAvatar(name: prayer.isAnonymous ? nil : prayer.author, path: prayer.authorAvatar)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(prayer.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(palette.ink)
                    Text(CommunityFormat.flag(prayer.authorCountry)).font(.subheadline)
                        .accessibilityLabel(prayer.authorCountry.map(CommunityFormat.countryName) ?? "")
                }
                Text(CommunityFormat.ago(prayer.createdAt)).font(.caption).foregroundStyle(palette.inkMuted)
            }
            Spacer()
            Menu {
                if prayer.isMine {
                    Button(action: onAnswer) { Label(prayer.isAnswered ? "Edit the answer" : "Mark as answered", systemImage: "checkmark.seal") }
                    Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
                } else {
                    Button(action: onReport) { Label("Report", systemImage: "flag") }
                    Button(role: .destructive, action: onBlock) { Label("Block this member", systemImage: "hand.raised") }
                }
            } label: {
                Image(systemName: "ellipsis").font(.body).foregroundStyle(palette.inkMuted).frame(width: 36, height: 32)
            }
            .accessibilityLabel("More options")
        }
    }

    private var answered: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Answered prayer", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.greenInk)
            if let note = prayer.answerNote, !note.isEmpty {
                Text(note).font(.footnote).foregroundStyle(palette.inkSoft)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(palette.greenInk.opacity(0.12)))
    }

    private func reactionButton(_ kind: PrayerReaction, title: String, count: Int, on: Bool, icon: String) -> some View {
        Button { onReact(kind) } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(count > 0 ? "\(title) \u{00B7} \(count)" : title)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(on ? palette.gold.opacity(0.22) : palette.surface))
            .overlay(Capsule().stroke(on ? palette.gold : palette.goldLine, lineWidth: on ? 1.5 : 1))
            .foregroundStyle(on ? palette.goldBright : palette.inkSoft)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// A round avatar: the member's photo, their initial, or a sparkle for an anonymous post.
struct CommunityAvatar: View {
    let name: String?
    let path: String?
    var size: CGFloat = 38
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            if let url = CommunityFormat.avatarURL(path) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initial
                }
            } else {
                initial
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(palette.goldLine))
        .accessibilityHidden(true)
    }

    private var initial: some View {
        ZStack {
            Circle().fill(palette.gold.opacity(0.18))
            if let first = name?.trimmingCharacters(in: .whitespaces).first {
                Text(String(first).uppercased()).font(.system(size: size * 0.42, weight: .semibold, design: .serif)).foregroundStyle(palette.goldBright)
            } else {
                Image(systemName: "sparkles").font(.system(size: size * 0.4)).foregroundStyle(palette.goldBright)
            }
        }
    }
}

// MARK: - Sharing a request

struct PrayerComposerView: View {

    var onPosted: () -> Void = {}

    @EnvironmentObject var store: CommunityStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var anonymous = false
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var showGuidelines = false
    @FocusState private var focused: Bool

    private let limit = 1000
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canPost: Bool { trimmed.count >= 10 && trimmed.count <= limit && !busy }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("What can we pray for?", text: $text, axis: .vertical)
                        .lineLimit(6...14)
                        .focused($focused)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(palette.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.goldLine))
                        .onChange(of: text) { if text.count > limit { text = String(text.prefix(limit)) } }
                        .accessibilityLabel("Prayer request")

                    HStack {
                        Text("\(trimmed.count)/\(limit)")
                            .font(.caption).foregroundStyle(trimmed.count >= 10 || trimmed.isEmpty ? palette.inkMuted : palette.roseInk)
                        Spacer()
                    }

                    Toggle("Post anonymously", isOn: $anonymous)
                        .tint(palette.gold)
                    Text("Anonymous posts hide your name and country on the wall. We still keep who wrote it, for moderation.")
                        .font(.caption).foregroundStyle(palette.inkMuted)

                    Text("Please avoid full names, phone numbers and addresses. Posts appear right away and can be reported by the community.")
                        .font(.footnote).foregroundStyle(palette.inkSoft)

                    Button { showGuidelines = true } label: {
                        Text("By sharing, you agree to the community guidelines.").font(.footnote).underline().foregroundStyle(palette.inkMuted)
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(palette.roseInk)
                    }
                }
                .padding(16)
                .readableWidth(640)
            }
            .themedScreen()
            .navigationTitle("Share a request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await post() } } label: {
                        if busy { ProgressView() } else { Text("Share").bold() }
                    }
                    .disabled(!canPost)
                }
            }
            .sheet(isPresented: $showGuidelines) { CommunityGuidelinesView() }
            .onAppear { focused = true }
        }
        .presentationDetents([.large])
    }

    private func post() async {
        busy = true
        errorMessage = nil
        defer { busy = false }
        do {
            try await store.post(body: trimmed, anonymous: anonymous)
            onPosted()
            dismiss()
        } catch {
            errorMessage = CommunityStore.message(error)
        }
    }
}

// MARK: - The answer

struct AnsweredSheet: View {

    let prayer: CommunityPrayer
    let save: (Bool, String) async throws -> Void

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var note: String
    @State private var busy = false
    @State private var errorMessage: String?

    init(prayer: CommunityPrayer, save: @escaping (Bool, String) async throws -> Void) {
        self.prayer = prayer
        self.save = save
        _note = State(initialValue: prayer.answerNote ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Share how God answered, so those who prayed can rejoice with you.")
                    .font(.subheadline).foregroundStyle(palette.inkSoft)
                TextField("How God answered (optional)", text: $note, axis: .vertical)
                    .lineLimit(3...8)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.goldLine))
                    .onChange(of: note) { if note.count > 500 { note = String(note.prefix(500)) } }
                if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(palette.roseInk) }
                if prayer.isAnswered {
                    Button("Mark as not answered", role: .destructive) { Task { await run(false) } }
                        .font(.subheadline)
                }
                Spacer()
            }
            .padding(16)
            .themedScreen()
            .navigationTitle("Answered prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await run(true) } } label: { if busy { ProgressView() } else { Text("Save").bold() } }
                        .disabled(busy)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func run(_ answered: Bool) async {
        busy = true
        defer { busy = false }
        do {
            try await save(answered, note.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            errorMessage = CommunityStore.message(error)
        }
    }
}

// MARK: - Reporting

struct ReportSheet: View {

    let title: String
    let send: (ReportReason, String) async throws -> Void

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason = .inappropriate
    @State private var details = ""
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Why are you reporting this?") {
                    ForEach(ReportReason.allCases) { option in
                        Button {
                            reason = option
                        } label: {
                            HStack {
                                Text(option.title).foregroundStyle(palette.ink)
                                Spacer()
                                if reason == option { Image(systemName: "checkmark").foregroundStyle(palette.gold) }
                            }
                        }
                        .accessibilityAddTraits(reason == option ? .isSelected : [])
                    }
                }
                .themedRows()

                Section(footer: Text("Our moderator reviews every report. A post reported by three members is hidden until it is reviewed.")) {
                    TextField("Anything else we should know? (optional)", text: $details, axis: .vertical)
                        .lineLimit(2...5)
                        .onChange(of: details) { if details.count > 500 { details = String(details.prefix(500)) } }
                }
                .themedRows()

                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(palette.roseInk).themedRows()
                }
            }
            .themedList()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await run() } } label: { if busy { ProgressView() } else { Text("Send report").bold() } }
                        .disabled(busy)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func run() async {
        busy = true
        defer { busy = false }
        do {
            try await send(reason, details)
            dismiss()
        } catch {
            errorMessage = CommunityStore.message(error)
        }
    }
}

// MARK: - Guidelines

struct CommunityGuidelinesView: View {

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Community Prayers is a place to carry one another\u{2019}s burdens (Galatians 6:2). When you post, please:")
                        .font(.subheadline).foregroundStyle(palette.inkSoft)
                    rule("Be kind and respectful. No hateful, abusive, sexual or violent content.")
                    rule("Protect privacy: don\u{2019}t share full names, phone numbers, addresses or other personal details, yours or anyone else\u{2019}s.")
                    rule("No advertising, spam, fundraising requests or links to sell something.")
                    rule("Don\u{2019}t impersonate others or post anything illegal.")

                    Text("Posts appear right away. Any member can report a post or a reply (\u{22EF} \u{2192} Report); reported posts are reviewed by our moderator, and a post reported by several members is hidden until it is reviewed. You can block a member from the same menu. We may remove any post, or suspend an account, that goes against these guidelines.")
                        .font(.subheadline).foregroundStyle(palette.inkSoft)

                    Text("You keep ownership of what you write. By sharing a community post you allow BibleWish to display it on the site and in the app. Your notes and your private prayer list are only shown to you.")
                        .font(.subheadline).foregroundStyle(palette.inkSoft)

                    HStack(spacing: 18) {
                        Button("Terms") { openURL(APIConfig.termsURL) }
                        Button("Privacy") { openURL(APIConfig.privacyURL) }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(16)
                .readableWidth(640)
            }
            .themedScreen()
            .navigationTitle("Community guidelines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle").foregroundStyle(palette.gold)
            Text(text).font(.subheadline).foregroundStyle(palette.ink)
        }
    }
}
