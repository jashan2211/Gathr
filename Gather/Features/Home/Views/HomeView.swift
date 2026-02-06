import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startDate) private var events: [Event]
    @State private var selectedEvent: Event?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    // Upcoming Events Section
                    if !upcomingEvents.isEmpty {
                        SectionHeader(title: "Upcoming", action: nil)

                        ForEach(upcomingEvents) { event in
                            EventCard(event: event)
                                .onTapGesture {
                                    selectedEvent = event
                                }
                        }
                    }

                    // Events you're attending
                    if !attendingEvents.isEmpty {
                        SectionHeader(title: "You're Going", action: nil)
                            .padding(.top, Spacing.md)

                        ForEach(attendingEvents) { event in
                            EventCard(event: event, variant: .compact)
                                .onTapGesture {
                                    selectedEvent = event
                                }
                        }
                    }

                    // Empty state
                    if events.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.plus",
                            title: "No events yet",
                            message: "Create your first event or wait for invitations"
                        )
                        .padding(.top, Spacing.xxl)
                    }
                }
                .horizontalPadding()
                .padding(.bottom, Layout.tabBarHeight + Spacing.md)
            }
            .navigationTitle("Home")
            .refreshable {
                // Refresh events
            }
            .navigationDestination(item: $selectedEvent) { event in
                EventDetailView(event: event)
            }
        }
    }

    private var upcomingEvents: [Event] {
        events.filter { $0.isUpcoming }
    }

    private var attendingEvents: [Event] {
        // TODO: Filter by user's RSVP status
        events.filter { $0.isUpcoming }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(GatherFont.title2)
                .foregroundStyle(Color.gatherPrimaryText)

            Spacer()

            if let action = action {
                Button("See All", action: action)
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.accentPurpleFallback)
            }
        }
        .padding(.top, Spacing.sm)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.gatherSecondaryText)

            Text(title)
                .font(GatherFont.headline)
                .foregroundStyle(Color.gatherPrimaryText)

            Text(message)
                .font(GatherFont.body)
                .foregroundStyle(Color.gatherSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .modelContainer(for: Event.self, inMemory: true)
}
