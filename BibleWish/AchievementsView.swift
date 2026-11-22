//
//  AchievementsView.swift
//  BibleWish
//
//  Badges for faithfulness: reading, going through the Bible, study and the seasons.
//

import SwiftUI

struct AchievementsView: View {

    @EnvironmentObject var achievements: AchievementsStore
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("\(achievements.earned.count) of \(achievements.badges.count) badges earned")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(palette.ink)

                ForEach(achievements.groups, id: \.self) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.uppercased())
                            .font(.system(.caption, design: .serif, weight: .semibold))
                            .tracking(2.5)
                            .foregroundStyle(palette.gold)

                        ForEach(achievements.badges.filter { $0.group == group }) { badge in
                            row(badge)
                        }
                    }
                }
            }
            .padding(16)
        }
        .themedScreen()
        .navigationTitle("Achievements")
    }

    private func row(_ badge: BadgeDefinition) -> some View {
        let earnedAt = achievements.earned[badge.id]
        let isEarned = earnedAt != nil

        return HStack(alignment: .top, spacing: 14) {
            Text(badge.icon)
                .font(.system(size: 28))
                .frame(width: 52, height: 52)
                .background(Circle().fill(isEarned ? palette.gold.opacity(0.18) : palette.surface))
                .overlay(Circle().stroke(isEarned ? palette.gold : palette.goldLine, lineWidth: isEarned ? 1.5 : 1))
                .saturation(isEarned ? 1 : 0)
                .opacity(isEarned ? 1 : 0.55)

            VStack(alignment: .leading, spacing: 4) {
                Text(badge.name)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(isEarned ? palette.ink : palette.inkSoft)

                Text(badge.description)
                    .font(.subheadline)
                    .foregroundStyle(palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if let earnedAt {
                    Text("Earned \(earnedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.goldBright)
                } else if badge.target > 1 {
                    ProgressView(value: achievements.fraction(badge))
                        .tint(palette.gold)
                    Text("\(achievements.current(badge)) / \(badge.target)")
                        .font(.caption)
                        .foregroundStyle(palette.inkMuted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .themedCard(cornerRadius: 14, fill: isEarned ? palette.gold.opacity(0.06) : nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge.name), \(isEarned ? "earned" : "not yet earned"). \(badge.description)")
    }
}

/// The banner shown when a badge unlocks.
struct BadgeToast: View {
    let badge: BadgeDefinition
    var onTap: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(badge.icon).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text("BADGE UNLOCKED")
                        .font(.system(.caption2, design: .serif, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(palette.gold)
                    Text(badge.name)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(palette.ink)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(palette.panel))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.gold.opacity(0.7)))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityLabel("Badge unlocked: \(badge.name)")
    }
}
