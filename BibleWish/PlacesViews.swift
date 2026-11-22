//
//  PlacesViews.swift
//
//  Places named in a chapter, and the Bible's journeys on a map.
//

import SwiftUI
import MapKit

// MARK: - Places in a chapter

struct ChapterPlacesView: View {

    let bookName: String
    let chapter: Int
    let mentions: [PlaceMention]

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $camera) {
                    ForEach(mentions) { mention in
                        Marker(mention.place.name, coordinate: mention.place.coordinate)
                            .tint(palette.gold)
                    }
                }
                .frame(height: 320)

                List(mentions) { mention in
                    Button {
                        withAnimation {
                            camera = .region(MKCoordinateRegion(
                                center: mention.place.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
                            ))
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mention.place.name)
                                .font(.system(.headline, design: .serif))
                                .foregroundStyle(palette.ink)
                            Text("\(mention.place.kind.capitalized) \u{00B7} verse\(mention.verses.count == 1 ? "" : "s") \(mention.verses.map(String.init).joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(palette.inkMuted)
                        }
                    }
                    .themedRows()
                }
                .themedList()
            }
            .navigationTitle("\(bookName) \(chapter)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Journeys

struct JourneysView: View {

    @Environment(\.palette) private var palette
    private let journeys = PlacesStore.shared.journeys

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(journeys) { journey in
                    NavigationLink(value: journey.id) {
                        HStack(spacing: 14) {
                            Circle().fill(journey.tint).frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(journey.title)
                                    .font(.system(.headline, design: .serif))
                                    .foregroundStyle(palette.ink)
                                Text(journey.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(palette.inkMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(palette.gold)
                        }
                        .padding(18)
                        .themedCard(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .readableWidth()
        }
        .themedScreen()
        .navigationTitle("Bible Maps")
        .navigationDestination(for: String.self) { id in
            if let journey = journeys.first(where: { $0.id == id }) {
                JourneyMapView(journey: journey)
            }
        }
    }
}

struct JourneyMapView: View {

    let journey: Journey

    @Environment(\.palette) private var palette
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $camera) {
                MapPolyline(coordinates: journey.stops.map(\.coordinate))
                    .stroke(journey.tint, lineWidth: 3)

                ForEach(Array(journey.stops.enumerated()), id: \.element.id) { index, stop in
                    Annotation(stop.label, coordinate: stop.coordinate) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(journey.tint))
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    }
                }
            }
            .frame(height: 340)

            List(Array(journey.stops.enumerated()), id: \.element.id) { index, stop in
                Button {
                    withAnimation {
                        camera = .region(MKCoordinateRegion(
                            center: stop.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
                        ))
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(journey.tint))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(stop.label)
                                .font(.system(.headline, design: .serif))
                                .foregroundStyle(palette.ink)
                            Text(stop.reference)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.goldBright)
                            Text(stop.note)
                                .font(.subheadline)
                                .foregroundStyle(palette.inkSoft)
                        }
                    }
                }
                .themedRows()
            }
            .themedList()
        }
        .navigationTitle(journey.title)
    }
}
