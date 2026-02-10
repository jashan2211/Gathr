import SwiftUI

// MARK: - Location Filter Sheet

struct LocationFilterSheet: View {
    let availableCities: [String]
    let availableStates: [String]
    let availableCountries: [String]

    @Binding var selectedCity: String?
    @Binding var selectedState: String?
    @Binding var selectedCountry: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // City
                    if !availableCities.isEmpty {
                        filterSection(
                            title: "City",
                            icon: "building.2.fill",
                            items: availableCities,
                            selected: selectedCity,
                            gradient: LinearGradient(
                                colors: [Color.accentPurpleFallback, Color.accentPurpleFallback.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        ) { city in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCity = selectedCity == city ? nil : city
                            }
                        }
                    }

                    // State
                    if !availableStates.isEmpty {
                        filterSection(
                            title: "State",
                            icon: "map.fill",
                            items: availableStates,
                            selected: selectedState,
                            gradient: LinearGradient(
                                colors: [Color.accentPinkFallback, Color.accentPinkFallback.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        ) { state in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedState = selectedState == state ? nil : state
                            }
                        }
                    }

                    // Country
                    if !availableCountries.isEmpty {
                        filterSection(
                            title: "Country",
                            icon: "globe",
                            items: availableCountries,
                            selected: selectedCountry,
                            gradient: LinearGradient(
                                colors: [Color.rsvpYesFallback, Color.rsvpYesFallback.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        ) { country in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCountry = selectedCountry == country ? nil : country
                            }
                        }
                    }

                    if availableCities.isEmpty && availableStates.isEmpty && availableCountries.isEmpty {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "map")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.gatherSecondaryText.opacity(0.5))
                            Text("No location data available")
                                .font(GatherFont.body)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Filter by Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedCity != nil || selectedState != nil || selectedCountry != nil {
                        Button("Reset") {
                            withAnimation {
                                selectedCity = nil
                                selectedState = nil
                                selectedCountry = nil
                            }
                        }
                        .foregroundStyle(Color.accentPurpleFallback)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentPurpleFallback)
                }
            }
        }
    }

    private func filterSection(
        title: String,
        icon: String,
        items: [String],
        selected: String?,
        gradient: LinearGradient,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(Color.accentPurpleFallback)
                Text(title)
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
            }

            // Chips
            GatherFlowLayout(spacing: Spacing.xs) {
                ForEach(items, id: \.self) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        Text(item)
                            .font(GatherFont.callout)
                            .fontWeight(selected == item ? .semibold : .regular)
                            .foregroundStyle(selected == item ? .white : Color.gatherPrimaryText)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                selected == item
                                    ? AnyShapeStyle(gradient)
                                    : AnyShapeStyle(Color.gatherSecondaryBackground)
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        selected == item ? Color.clear : Color.gatherSecondaryText.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .scaleEffect(selected == item ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected == item)
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct GatherFlowLayout: SwiftUI.Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }

        let totalHeight = currentY + rowHeight
        return ArrangementResult(
            positions: positions,
            sizes: sizes,
            size: CGSize(width: maxWidth, height: totalHeight)
        )
    }

    struct ArrangementResult {
        var positions: [CGPoint]
        var sizes: [CGSize]
        var size: CGSize
    }
}
