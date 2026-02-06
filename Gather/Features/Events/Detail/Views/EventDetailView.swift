import SwiftUI
import MapKit

struct EventDetailView: View {
    let event: Event
    @State private var showRSVPSheet = false
    @State private var showShareSheet = false
    @State private var showGuestList = false
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Section
                heroSection

                // Content
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Title & Host
                    titleSection

                    Divider()

                    // Date & Time
                    dateTimeSection

                    // Location
                    if let location = event.location {
                        locationSection(location)
                    }

                    Divider()

                    // Description
                    if let description = event.eventDescription {
                        descriptionSection(description)
                        Divider()
                    }

                    // Guest List Preview
                    guestListSection

                    // Comments Section (placeholder)
                    commentsSection
                }
                .horizontalPadding()
                .padding(.bottom, 120) // Space for floating RSVP button
            }
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) {
            rsvpButton
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share Event", systemImage: "square.and.arrow.up")
                    }

                    if isHost {
                        Button {
                            // Edit event
                        } label: {
                            Label("Edit Event", systemImage: "pencil")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showRSVPSheet) {
            RSVPSheet(event: event)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(event: event)
        }
        .sheet(isPresented: $showGuestList) {
            GuestListSheet(event: event)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Background
            if let heroURL = event.heroMediaURL {
                AsyncImage(url: heroURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    heroPlaceholder
                }
            } else {
                heroPlaceholder
            }

            // Gradient overlay
            LinearGradient.heroOverlay

            // Capacity badge
            if let capacity = event.capacity {
                VStack {
                    HStack {
                        Spacer()
                        CapacityBadge(
                            attending: event.attendingCount,
                            capacity: capacity
                        )
                        .padding()
                    }
                    Spacer()
                }
            }
        }
        .frame(height: Layout.heroImageHeight)
    }

    private var heroPlaceholder: some View {
        LinearGradient(
            colors: [
                Color.accentPurpleFallback,
                Color.accentPinkFallback
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(event.title)
                .font(GatherFont.title)
                .foregroundStyle(Color.gatherPrimaryText)

            if let host = event.host {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.gatherSecondaryBackground)
                        .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                        .overlay {
                            Text(host.name.prefix(1))
                                .font(GatherFont.caption)
                        }

                    Text("Hosted by \(host.name)")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Date & Time Section

    private var dateTimeSection: some View {
        HStack(spacing: Spacing.md) {
            // Calendar icon
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color.accentPurpleFallback.opacity(0.1))
                    .frame(width: 48, height: 48)

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
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(formattedFullDate)
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text(formattedTime)
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            Spacer()

            // Add to calendar button
            Button {
                // Add to calendar
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(Color.accentPurpleFallback)
            }
        }
    }

    // MARK: - Location Section

    private func locationSection(_ location: EventLocation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.accentPinkFallback.opacity(0.1))
                        .frame(width: 48, height: 48)

                    Image(systemName: location.isVirtual ? "video.fill" : "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentPinkFallback)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(location.name)
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)

                    if let address = location.address {
                        Text(address)
                            .font(GatherFont.callout)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }

                Spacer()

                if !location.isVirtual {
                    Button {
                        // Open in maps
                    } label: {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentPinkFallback)
                    }
                }
            }

            // Map preview
            if location.hasCoordinates, let lat = location.latitude, let lon = location.longitude {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker(location.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .disabled(true)
            }
        }
    }

    // MARK: - Description Section

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("About")
                .font(GatherFont.headline)
                .foregroundStyle(Color.gatherPrimaryText)

            Text(description)
                .font(GatherFont.body)
                .foregroundStyle(Color.gatherSecondaryText)
        }
    }

    // MARK: - Guest List Section

    private var guestListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Guests")
                    .font(GatherFont.headline)

                Spacer()

                Button {
                    showGuestList = true
                } label: {
                    Text("See All")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.accentPurpleFallback)
                }
            }

            // Guest summary
            HStack(spacing: Spacing.md) {
                GuestCountPill(count: event.attendingCount, label: "Going", status: .attending)
                GuestCountPill(count: event.maybeCount, label: "Maybe", status: .maybe)
                if event.pendingCount > 0 {
                    GuestCountPill(count: event.pendingCount, label: "Pending", status: .pending)
                }
            }

            // Guest avatars preview
            if !event.guests.isEmpty {
                HStack(spacing: -8) {
                    ForEach(event.guests.prefix(5)) { guest in
                        Circle()
                            .fill(Color.gatherSecondaryBackground)
                            .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                            .overlay {
                                Text(guest.name.prefix(1))
                                    .font(.caption2)
                            }
                            .overlay {
                                Circle()
                                    .stroke(Color.gatherBackground, lineWidth: 2)
                            }
                    }

                    if event.guests.count > 5 {
                        Circle()
                            .fill(Color.gatherTertiaryBackground)
                            .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                            .overlay {
                                Text("+\(event.guests.count - 5)")
                                    .font(.caption2)
                                    .foregroundStyle(Color.gatherSecondaryText)
                            }
                    }
                }
            }
        }
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Comments")
                    .font(GatherFont.headline)

                Spacer()

                Text("\(event.comments.count)")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            if event.comments.isEmpty {
                Text("No comments yet. Be the first!")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .padding(.vertical, Spacing.md)
            }
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - RSVP Button

    private var rsvpButton: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                // Current status (if already responded)
                VStack(alignment: .leading) {
                    Text("Your RSVP")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                    Text("Not responded")
                        .font(GatherFont.headline)
                }

                Spacer()

                Button {
                    showRSVPSheet = true
                } label: {
                    Text("RSVP")
                        .font(GatherFont.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.sm)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Helpers

    private var isHost: Bool {
        event.host?.id == authManager.currentUser?.id
    }

    private var monthAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: event.startDate).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: event.startDate)
    }

    private var formattedFullDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: event.startDate)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var result = formatter.string(from: event.startDate)
        if let endDate = event.endDate {
            result += " - \(formatter.string(from: endDate))"
        }
        return result
    }
}

// MARK: - Supporting Views

struct CapacityBadge: View {
    let attending: Int
    let capacity: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "person.2.fill")
                .font(.caption)
            Text("\(attending)/\(capacity)")
                .font(GatherFont.caption)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

struct GuestCountPill: View {
    let count: Int
    let label: String
    let status: RSVPStatus

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(Color.forRSVPStatus(status))
                .frame(width: 8, height: 8)
            Text("\(count) \(label)")
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EventDetailView(
            event: Event(
                title: "Summer Rooftop Party",
                eventDescription: "Join us for an amazing summer party with great music, food, and drinks. Dress code: summer casual.",
                startDate: Date().addingTimeInterval(86400 * 7),
                endDate: Date().addingTimeInterval(86400 * 7 + 14400),
                location: EventLocation(
                    name: "The Rooftop Lounge",
                    address: "123 Main Street, San Francisco, CA"
                ),
                capacity: 50
            )
        )
        .environmentObject(AuthManager())
    }
}
