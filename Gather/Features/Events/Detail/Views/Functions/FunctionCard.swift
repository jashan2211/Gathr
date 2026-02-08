import SwiftUI

struct FunctionCard: View {
    let function: EventFunction
    let event: Event

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
                        .foregroundStyle(Color.gatherPrimaryText)
                }
                .frame(width: 48, height: 48)
                .background(Color.accentPurpleFallback.opacity(0.1))
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
            HStack(spacing: Spacing.lg) {
                StatPill(
                    icon: "checkmark.circle.fill",
                    count: function.attendingCount,
                    label: "Attending",
                    color: .green
                )

                StatPill(
                    icon: "questionmark.circle.fill",
                    count: function.maybeCount,
                    label: "Maybe",
                    color: .orange
                )

                StatPill(
                    icon: "paperplane.fill",
                    count: function.sentCount,
                    label: "Invited",
                    color: .blue
                )

                Spacer()
            }
        }
        .padding()
        .background(Color.gatherSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
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
                    .background(Color.green)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Helpers

    private var monthAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: function.date).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: function.date)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var result = formatter.string(from: function.date)
        if let endTime = function.endTime {
            result += " - \(formatter.string(from: endTime))"
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
        }
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
