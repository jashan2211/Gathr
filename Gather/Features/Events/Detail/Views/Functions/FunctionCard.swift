import SwiftUI

struct FunctionCard: View {
    let function: EventFunction
    let event: Event
    /// Highlights the next upcoming function with a category-accent border.
    var isNextUp: Bool = false

    private var accent: Color {
        Color.forCategory(event.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                // Date badge
                VStack(spacing: 0) {
                    Text(monthAbbreviation)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text(dayNumber)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.accentPurpleFallback)
                }
                .frame(width: 48, height: 48)
                .background(Color.gatherElevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(function.name)
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text(formattedTime)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                // Status indicator
                statusBadge

                // The whole card opens the detail sheet — say so.
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.gatherTertiaryText)
            }

            // Location
            if let location = function.location {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Color.accentPinkFallback)
                    Text(location.name)
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }

            // Dress Code
            if let dressCode = function.displayDressCode {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "tshirt.fill")
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text(dressCode)
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }

            Divider()

            // RSVP Stats
            HStack(spacing: Spacing.md) {
                StatPill(
                    icon: "checkmark.circle.fill",
                    count: function.attendingCount,
                    label: "Going",
                    color: .rsvpYesFallback
                )

                StatPill(
                    icon: "questionmark.circle.fill",
                    count: function.maybeCount,
                    label: "Maybe",
                    color: .rsvpMaybeFallback
                )

                StatPill(
                    icon: "paperplane.fill",
                    count: function.sentCount,
                    label: "Invited",
                    color: .neonBlue
                )

                Spacer()
            }
        }
        .padding()
        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .surfaceCard()
        // "Next up" reads as a category-accent ring around the card.
        .overlay {
            if isNextUp {
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .strokeBorder(accent.opacity(0.65), lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(function.name), \(formattedTime)\(function.location.map { ", \($0.name)" } ?? "")\(isNextUp ? ", next up" : "")")
        .accessibilityHint("Double tap to view details and RSVP")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Group {
            if function.isPast {
                Text("Past")
                    .font(GatherFont.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.gatherSecondaryText)
                    .clipShape(Capsule())
            } else if function.isOngoing {
                Text("Now")
                    .font(GatherFont.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.rsvpYesFallback)
                    .clipShape(Capsule())
            } else if isNextUp {
                Text("Next up")
                    .font(GatherFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.onCategory(event.category))
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(accent)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Helpers

    private var monthAbbreviation: String {
        GatherDateFormatter.monthAbbrev.string(from: function.date).uppercased()
    }

    private var dayNumber: String {
        GatherDateFormatter.dayNumber.string(from: function.date)
    }

    private var formattedTime: String {
        var result = GatherDateFormatter.timeOnly.string(from: function.date)
        if let endTime = function.endTime {
            result += " - \(GatherDateFormatter.timeOnly.string(from: endTime))"
        }
        return result
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text("\(count)")
                .font(GatherFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.gatherPrimaryText)
            // Visible label so counts read at a glance ("8 Going", not
            // an icon-decoder puzzle).
            Text(label)
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) \(label)")
    }
}

// MARK: - Preview

#Preview {
    let function = EventFunction(
        name: "Sangeet",
        functionDescription: "Music and dance night",
        date: Date().addingTimeInterval(86400 * 3),
        endTime: Date().addingTimeInterval(86400 * 3 + 14400),
        location: EventLocation(name: "Grand Ballroom", address: "123 Main St"),
        dressCode: .traditional,
        eventId: UUID()
    )
    let event = Event(title: "Wedding", startDate: Date())

    FunctionCard(function: function, event: event)
        .padding()
}
