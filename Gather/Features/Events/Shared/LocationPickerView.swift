import SwiftUI
import MapKit

/// A location picker sheet with search suggestions and a map preview.
struct LocationPickerView: View {
    @StateObject private var searchManager = LocationSearchManager()
    @Environment(\.dismiss) private var dismiss

    let onSelect: (String, String?, String?, String?, String?, Double, Double) -> Void

    @State private var selectedMapItem: MKMapItem?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var isResolving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.gatherSecondaryText)
                    TextField("Search for a venue or address...", text: $searchManager.query)
                        .font(GatherFont.body)
                        .autocorrectionDisabled()
                }
                .padding(Spacing.sm)
                .background(Color.gatherSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, Spacing.sm)

                if let item = selectedMapItem {
                    // Selected location preview
                    selectedLocationView(item)
                } else if searchManager.isSearching {
                    ProgressView()
                        .padding(.top, Spacing.lg)
                    Spacer()
                } else if !searchManager.suggestions.isEmpty {
                    suggestionsList
                } else if searchManager.query.isEmpty {
                    emptyPrompt
                } else {
                    noResults
                }
            }
            .navigationTitle("Find Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if isResolving {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Finding location...")
                                .padding()
                                .surfaceCard(cornerRadius: CornerRadius.md)
                        }
                }
            }
        }
    }

    // MARK: - Suggestions List

    private var suggestionsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.xs) {
                ForEach(searchManager.suggestions, id: \.self) { suggestion in
                    Button {
                        selectSuggestion(suggestion)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentPinkFallback)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(GatherFont.callout)
                                    .foregroundStyle(Color.gatherPrimaryText)
                                    .lineLimit(1)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(GatherFont.caption)
                                        .foregroundStyle(Color.gatherSecondaryText)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                        .padding(Spacing.sm)
                        .surfaceCard(cornerRadius: CornerRadius.md)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - Selected Location

    private func selectedLocationView(_ item: MKMapItem) -> some View {
        VStack(spacing: Spacing.md) {
            // Map
            Map(position: $cameraPosition) {
                Marker(
                    item.name ?? "Location",
                    coordinate: item.placemark.coordinate
                )
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Spacing.sm)

            // Info card
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.name ?? "Unknown")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)

                if let address = item.placemark.formattedAddress {
                    Text(address)
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .surfaceCard(cornerRadius: CornerRadius.lg)
            .padding(.horizontal, Layout.horizontalPadding)

            Spacer()

            // Primary select + secondary search-again actions
            VStack(spacing: Spacing.sm) {
                Button {
                    confirmSelection()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.callout)
                        Text("Use This Location")
                            .font(GatherFont.callout)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.buttonHeight)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
                }

                Button {
                    selectedMapItem = nil
                    cameraPosition = .automatic
                } label: {
                    Text("Search Again")
                        .font(GatherFont.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.buttonHeight)
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Spacing.md)
        }
    }

    // MARK: - Empty / No Results

    private var emptyPrompt: some View {
        VStack {
            Spacer()
            GatherEmptyState(
                icon: "map",
                title: "Find your spot",
                message: "Search for a venue, address, or city to pin your event."
            )
            Spacer()
        }
    }

    private var noResults: some View {
        VStack {
            Spacer()
            GatherEmptyState(
                icon: "magnifyingglass",
                title: "No locations found",
                message: "Try a different name, or search a nearby street or city."
            )
            Spacer()
        }
    }

    // MARK: - Actions

    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        isResolving = true
        Task {
            if let mapItem = await searchManager.resolve(suggestion) {
                selectedMapItem = mapItem
                let coord = mapItem.placemark.coordinate
                cameraPosition = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
            }
            isResolving = false
        }
    }

    private func confirmSelection() {
        guard let item = selectedMapItem else { return }
        let placemark = item.placemark
        let name = item.name ?? placemark.name ?? "Location"
        let address = placemark.formattedAddress
        let city = placemark.locality
        let state = placemark.administrativeArea
        let country = placemark.country
        let lat = placemark.coordinate.latitude
        let lon = placemark.coordinate.longitude
        onSelect(name, address, city, state, country, lat, lon)
        dismiss()
    }
}

// MARK: - CLPlacemark Extension

extension CLPlacemark {
    var formattedAddress: String? {
        var parts: [String] = []
        if let street = thoroughfare {
            if let number = subThoroughfare {
                parts.append("\(number) \(street)")
            } else {
                parts.append(street)
            }
        }
        if let city = locality { parts.append(city) }
        if let state = administrativeArea { parts.append(state) }
        if let zip = postalCode { parts.append(zip) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
