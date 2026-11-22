//
//  LeaderboardView.swift
//
//  The reading leaderboard, like biblewish.com/leaderboard: chapters read this week, month or year
//  (at most 40 a day count), your own place, what the community has read together, and the
//  countries. Members choose whether they are listed (Settings \u{2192} Account).
//

import SwiftUI

struct LeaderboardView: View {

    /// Changes when the screen is pulled to refresh.
    var reloadToken = 0

    @EnvironmentObject var store: CommunityStore
    @EnvironmentObject var auth: AuthStore
    @Environment(\.palette) private var palette

    @State private var period: LeaderboardPeriod = .week
    @State private var board: Leaderboard?
    @State private var failure: String?
    @State private var showSignIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Period", selection: $period) {
                ForEach(LeaderboardPeriod.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if let board {
                Text(CommunityFormat.range(start: board.start, end: board.end))
                    .font(.footnote).foregroundStyle(palette.inkMuted)
                goal(board.community)
                mine(board)
                leaders(board)
                if !board.countries.isEmpty { countries(board.countries) }
                Text("Chapters read, counted once a day each, up to 40 a day. Re-reading counts. Nobody is ranked in the app\u{2019}s badges.")
                    .font(.caption).foregroundStyle(palette.inkMuted).padding(.top, 4)
            } else if let failure {
                VStack(spacing: 10) {
                    Text(failure).font(.subheadline).foregroundStyle(palette.inkMuted).multilineTextAlignment(.center)
                    Button("Try again") { Task { await load() } }.font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
            }
        }
        .task(id: "\(period.rawValue)-\(reloadToken)-\(auth.user?.id ?? 0)") { await load() }
        .sheet(isPresented: $showSignIn) { SignInView() }
    }

    private func load() async {
        do {
            board = try await store.leaderboard(period)
            failure = nil
        } catch is CancellationError {
            return
        } catch {
            if board == nil { failure = CommunityStore.message(error) }
        }
    }

    // MARK: Pieces

    private func goal(_ community: LeaderboardCommunity) -> some View {
        let fraction = community.goal > 0 ? min(1, Double(community.chapters) / Double(community.goal)) : 0
        return VStack(alignment: .leading, spacing: 8) {
            Text("READING TOGETHER").font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(palette.gold)
            Text("\(community.chapters.formatted()) chapters read by \(community.readers.formatted()) reader\(community.readers == 1 ? "" : "s")")
                .font(.system(.headline, design: .serif)).foregroundStyle(palette.ink)
            ProgressView(value: fraction).tint(palette.gold)
            Text("Goal: \(community.goal.formatted()) chapters").font(.caption).foregroundStyle(palette.inkMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(cornerRadius: 14)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func mine(_ board: Leaderboard) -> some View {
        if let me = board.me {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR PLACE").font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(palette.gold)
                if let rank = me.rank {
                    Text("#\(rank) \u{00B7} \(me.chapters.formatted()) chapter\(me.chapters == 1 ? "" : "s")")
                        .font(.system(.title3, design: .serif)).foregroundStyle(palette.ink)
                    if let behind = me.behindNext, behind > 0 {
                        Text("\(behind) more to pass the next reader").font(.footnote).foregroundStyle(palette.inkSoft)
                    }
                } else {
                    Text("Read a chapter to join the board.").font(.subheadline).foregroundStyle(palette.inkSoft)
                }
                if !me.listed {
                    Text("You are hidden from the list. Only you see this. Change it in Settings \u{2192} Account.")
                        .font(.caption).foregroundStyle(palette.inkMuted)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(palette.gold.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.gold.opacity(0.5)))
            .accessibilityElement(children: .combine)
        } else {
            Button { showSignIn = true } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus").foregroundStyle(palette.gold)
                    Text("Sign in to see your place and join the board").font(.subheadline).foregroundStyle(palette.inkSoft)
                    Spacer()
                }
                .padding(14)
                .themedCard(cornerRadius: 14)
            }
            .buttonStyle(.plain)
        }
    }

    private func leaders(_ board: Leaderboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOP READERS").font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(palette.gold)
                .accessibilityAddTraits(.isHeader)
            if board.leaders.isEmpty {
                Text("No one has read this period yet. Be the first.").font(.subheadline).foregroundStyle(palette.inkMuted)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ForEach(board.leaders) { entry in row(entry) }
            }
        }
    }

    private func row(_ entry: LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            Text(medal(entry.rank))
                .font(entry.rank <= 3 ? .title3 : .subheadline.weight(.semibold))
                .foregroundStyle(palette.inkSoft)
                .frame(width: 34)
            CommunityAvatar(name: entry.name, path: entry.avatarUrl, size: 34)
            HStack(spacing: 6) {
                Text(entry.name).font(.subheadline.weight(entry.isMe ? .bold : .regular)).foregroundStyle(palette.ink).lineLimit(1)
                Text(CommunityFormat.flag(entry.country)).font(.subheadline)
                if entry.isMe { Text("You").font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(palette.gold.opacity(0.25))).foregroundStyle(palette.goldBright) }
            }
            Spacer(minLength: 4)
            Text(entry.chapters.formatted()).font(.system(.headline, design: .serif)).foregroundStyle(palette.goldBright)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(entry.isMe ? palette.gold.opacity(0.1) : palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(entry.isMe ? palette.gold.opacity(0.5) : palette.goldLine))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Number \(entry.rank), \(entry.name)\(entry.isMe ? ", you" : ""), \(entry.chapters) chapters")
    }

    private func medal(_ rank: Int) -> String {
        switch rank {
        case 1: return "\u{1F947}"
        case 2: return "\u{1F948}"
        case 3: return "\u{1F949}"
        default: return "\(rank)"
        }
    }

    private func countries(_ list: [LeaderboardCountry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COUNTRIES READING").font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(palette.gold)
                .accessibilityAddTraits(.isHeader)
            ForEach(list) { entry in
                HStack(spacing: 10) {
                    Text(CommunityFormat.flag(entry.country)).font(.title3)
                    Text(CommunityFormat.countryName(entry.country)).font(.subheadline).foregroundStyle(palette.ink)
                    Spacer()
                    Text("\(entry.chapters.formatted()) \u{00B7} \(entry.readers) reader\(entry.readers == 1 ? "" : "s")")
                        .font(.footnote).foregroundStyle(palette.inkSoft)
                }
                .padding(.vertical, 6).padding(.horizontal, 12)
                .themedCard(cornerRadius: 10)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
