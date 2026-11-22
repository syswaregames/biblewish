//
//  PlansView.swift
//  BibleWish
//
//  Your reading plans and the catalog of plans to start.
//

import SwiftUI

struct PlansView: View {

    @EnvironmentObject var viewModel: BibleViewModel
    @EnvironmentObject var plansStore: PlansStore
    @Environment(\.palette) private var palette

    private var startedPlans: [PlanInfo] {
        plansStore.catalog.filter { plansStore.userPlan($0.id) != nil }
    }

    private var availablePlans: [PlanInfo] {
        plansStore.catalog.filter { plansStore.userPlan($0.id) == nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !startedPlans.isEmpty {
                    sectionLabel("Your plans")
                    ForEach(startedPlans) { plan in
                        NavigationLink(value: plan.id) {
                            startedCard(plan)
                        }
                        .buttonStyle(.plain)
                    }
                }

                BibleProgressCard()
                    .padding(.top, startedPlans.isEmpty ? 0 : 8)

                if !availablePlans.isEmpty {
                    sectionLabel(startedPlans.isEmpty ? "Choose a plan" : "More plans")
                        .padding(.top, startedPlans.isEmpty ? 0 : 8)
                    ForEach(availablePlans) { plan in
                        availableCard(plan)
                    }
                }
            }
            .padding(16)
        }
        .themedScreen()
        .navigationTitle("Reading Plans")
        .navigationDestination(for: String.self) { planId in
            PlanDetailView(planId: planId)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(.caption, design: .serif, weight: .semibold))
            .tracking(2.5)
            .foregroundStyle(palette.gold)
            .accessibilityAddTraits(.isHeader)
    }

    private func startedCard(_ plan: PlanInfo) -> some View {
        let summary = plansStore.summary(for: plan.id)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(plan.title)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(palette.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(palette.gold)
            }

            if let summary {
                ProgressView(value: summary.fraction)
                    .tint(palette.gold)

                HStack(spacing: 12) {
                    Text(summary.percentLabel)
                    Text(summary.status.text)
                    if summary.streak > 0 {
                        Label("\(summary.streak)", systemImage: "flame.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption)
                .foregroundStyle(palette.inkMuted)

                if let next = summary.nextDay {
                    Text("Day \(next): \(PlansStore.label(forDay: summary.days[next - 1], bookNames: viewModel.books.map(\.name)))")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(palette.goldBright)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(cornerRadius: 16)
    }

    private func availableCard(_ plan: PlanInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.title)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(palette.ink)

            Text(plan.description)
                .font(.subheadline)
                .foregroundStyle(palette.inkSoft)

            Text("\(plan.days) days \u{00B7} \(plan.chapters) chapters \u{00B7} about \(plan.minutesPerDay) min a day")
                .font(.caption)
                .foregroundStyle(palette.inkMuted)

            Button {
                plansStore.start(plan.id)
            } label: {
                Text("Start plan")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(palette.gold.opacity(0.2)))
                    .overlay(Capsule().stroke(palette.gold.opacity(0.6)))
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(cornerRadius: 16)
    }
}
