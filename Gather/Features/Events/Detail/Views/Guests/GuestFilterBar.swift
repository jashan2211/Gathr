import SwiftUI

struct GuestFilterBar: View {
    let event: Event
    @Binding var filterFunction: EventFunction?
    @Binding var filterStatus: GuestsTab.GuestFilter

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Function Filter (if event has functions)
            if !event.functions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        FilterPill(
                            title: "All Functions",
                            isSelected: filterFunction == nil,
                            action: { filterFunction = nil }
                        )

                        ForEach(sortedFunctions) { function in
                            FilterPill(
                                title: function.name,
                                isSelected: filterFunction?.id == function.id,
                                action: { filterFunction = function }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Status Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(GuestsTab.GuestFilter.allCases, id: \.self) { status in
                        StatusFilterPill(
                            status: status,
                            isSelected: filterStatus == status,
                            action: { filterStatus = status }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(Color.gatherBackground)
    }

    private var sortedFunctions: [EventFunction] {
        event.functions.sorted { $0.date < $1.date }
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(GatherFont.caption)
                .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(isSelected ? Color.accentPurpleFallback : Color.gatherSecondaryBackground)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Status Filter Pill

struct StatusFilterPill: View {
    let status: GuestsTab.GuestFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(colorForStatus)
                    .frame(width: 6, height: 6)

                Text(status.rawValue)
                    .font(GatherFont.caption)
            }
            .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(isSelected ? colorForStatus : Color.gatherSecondaryBackground)
            .clipShape(Capsule())
        }
    }

    private var colorForStatus: Color {
        switch status {
        case .all: return .purple
        case .pending: return .gray
        case .sent: return .blue
        case .confirmed: return .green
        case .declined: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var filterFunction: EventFunction? = nil
    @Previewable @State var filterStatus: GuestsTab.GuestFilter = .all

    let event = Event(title: "Wedding", startDate: Date())

    GuestFilterBar(
        event: event,
        filterFunction: $filterFunction,
        filterStatus: $filterStatus
    )
}
