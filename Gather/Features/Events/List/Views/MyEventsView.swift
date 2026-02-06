import SwiftUI
import SwiftData

struct MyEventsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startDate) private var events: [Event]
    @State private var selectedTab: EventTab = .hosting
    @State private var selectedEvent: Event?

    enum EventTab: String, CaseIterable {
        case hosting = "Hosting"
        case attending = "Attending"
        case past = "Past"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Control
                Picker("Events", selection: $selectedTab) {
                    ForEach(EventTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .horizontalPadding()
                .padding(.vertical, Spacing.sm)

                // Event List
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(filteredEvents) { event in
                            EventCard(event: event, variant: selectedTab == .hosting ? .host : .guest)
                                .onTapGesture {
                                    selectedEvent = event
                                }
                        }

                        if filteredEvents.isEmpty {
                            EmptyStateView(
                                icon: emptyStateIcon,
                                title: emptyStateTitle,
                                message: emptyStateMessage
                            )
                            .padding(.top, Spacing.xxl)
                        }
                    }
                    .horizontalPadding()
                    .padding(.bottom, Layout.tabBarHeight + Spacing.md)
                }
            }
            .navigationTitle("My Events")
            .navigationDestination(item: $selectedEvent) { event in
                EventDetailView(event: event)
            }
        }
    }

    private var filteredEvents: [Event] {
        switch selectedTab {
        case .hosting:
            // TODO: Filter by current user as host
            return events.filter { $0.isUpcoming }
        case .attending:
            // TODO: Filter by user's attending RSVP
            return []
        case .past:
            return events.filter { $0.isPast }
        }
    }

    private var emptyStateIcon: String {
        switch selectedTab {
        case .hosting: return "calendar.badge.plus"
        case .attending: return "ticket"
        case .past: return "clock"
        }
    }

    private var emptyStateTitle: String {
        switch selectedTab {
        case .hosting: return "No events hosted"
        case .attending: return "No events to attend"
        case .past: return "No past events"
        }
    }

    private var emptyStateMessage: String {
        switch selectedTab {
        case .hosting: return "Create your first event to get started"
        case .attending: return "RSVP to events to see them here"
        case .past: return "Your past events will appear here"
        }
    }
}

// MARK: - Preview

#Preview {
    MyEventsView()
        .modelContainer(for: Event.self, inMemory: true)
}
