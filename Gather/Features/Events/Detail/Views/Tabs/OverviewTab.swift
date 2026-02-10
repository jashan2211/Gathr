import SwiftUI
import MapKit
import EventKit

struct OverviewTab: View {
    @Bindable var event: Event
    @Binding var showGuestList: Bool
    @Binding var showRSVPSheet: Bool
    @EnvironmentObject var authManager: AuthManager
    @State private var showSendInvites = false
    @State private var showAddGuest = false
    @State private var showCalendarAlert = false
    @State private var calendarAlertMessage = ""
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Quick Actions (for hosts)
                if isHost {
                    quickActionsSection
                }

                // RSVP Summary Card
                rsvpSummaryCard

                // Date & Time
                dateTimeSection

                // Location
                if let location = event.location {
                    locationSection(location)
                }

                // Description
                if let description = event.eventDescription {
                    descriptionSection(description)
                }

                // Upcoming Functions
                if !event.functions.isEmpty {
                    upcomingFunctionsSection
                }

                // Who's Going (avatar stack + names)
                if !event.guests.isEmpty {
                    whosGoingSection
                }

                // Recent Activity (if has guests)
                if !event.guests.isEmpty && isHost {
                    recentActivitySection
                }
            }
            .horizontalPadding()
            .padding(.top, Spacing.md)
            .padding(.bottom, Layout.scrollBottomInset)
        }
        .sheet(isPresented: $showSendInvites) {
            SendInvitesSheet(event: event, preselectedGuests: event.guests.map { $0.id })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddGuest) {
            AddGuestSheet(event: event)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Calendar", isPresented: $showCalendarAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calendarAlertMessage)
        }
        .sheet(isPresented: $showShareSheet) {
            let deepLink = "gather://event/\(event.id.uuidString)"
            let shareText = "\(event.title)\n\(event.startDate.formatted(date: .abbreviated, time: .shortened))"
            let shareItems: [String] = [shareText, deepLink]
            ShareActivitySheet(items: shareItems)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Is Host Check

    private var isHost: Bool {
        event.hostId == authManager.currentUser?.id
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: Spacing.sm) {
            QuickActionCard(
                icon: "person.badge.plus",
                title: "Add Guest",
                color: .accentPurpleFallback
            ) {
                showAddGuest = true
            }
            .bouncyAppear(delay: 0)

            QuickActionCard(
                icon: "paperplane.fill",
                title: "Send Invites",
                color: .neonBlue
            ) {
                showSendInvites = true
            }
            .bouncyAppear(delay: 0.05)

            QuickActionCard(
                icon: "square.and.arrow.up",
                title: "Share",
                color: .mintGreen
            ) {
                showShareSheet = true
            }
            .bouncyAppear(delay: 0.1)
        }
    }

    // MARK: - RSVP Summary Card

    private var rsvpSummaryCard: some View {
        VStack(spacing: Spacing.md) {
            // Header
            HStack {
                Text("Guest Summary")
                    .font(GatherFont.headline)

                Spacer()

                Text("\(event.guests.count) invited")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .contentTransition(.numericText())
            }

            // Progress Bars
            VStack(spacing: Spacing.sm) {
                RSVPProgressRow(
                    label: "Confirmed",
                    count: event.attendingCount,
                    total: event.guests.count,
                    color: .rsvpYesFallback,
                    icon: "checkmark.circle.fill"
                )

                RSVPProgressRow(
                    label: "Maybe",
                    count: maybeCount,
                    total: event.guests.count,
                    color: .rsvpMaybeFallback,
                    icon: "questionmark.circle.fill"
                )

                RSVPProgressRow(
                    label: "Declined",
                    count: declinedCount,
                    total: event.guests.count,
                    color: .rsvpNoFallback,
                    icon: "xmark.circle.fill"
                )

                RSVPProgressRow(
                    label: "Pending",
                    count: pendingCount,
                    total: event.guests.count,
                    color: .gatherSecondaryText,
                    icon: "clock.fill"
                )
            }

            // Total Attending
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Attending")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                    Text("\(totalAttending)")
                        .font(GatherFont.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .contentTransition(.numericText())
                }

                Spacer()

                Text("including +1s")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(.top, Spacing.xs)
        }
        .padding()
        .glassCard()
        .bouncyAppear()
    }

    // MARK: - Date & Time Section

    private var dateTimeSection: some View {
        HStack(spacing: Spacing.md) {
            // Calendar Icon
            VStack(spacing: 0) {
                Text(monthAbbreviation)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.accentPurpleFallback)

                Text(dayNumber)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
            }
            .frame(width: 56)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(formattedFullDate)
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text(formattedTime)
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)

                if let endDate = event.endDate, !Calendar.current.isDate(event.startDate, inSameDayAs: endDate) {
                    Text("Multi-day event")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.accentPurpleFallback)
                }
            }

            Spacer()

            Button {
                Task {
                    calendarAlertMessage = await CalendarService.shared.addEventToCalendar(event: event)
                    showCalendarAlert = true
                }
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(Color.accentPurpleFallback)
                    .frame(width: 44, height: 44)
                    .background(Color.accentPurpleFallback.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Location Section

    private func locationSection(_ location: EventLocation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                Image(systemName: location.isVirtual ? "video.fill" : "mappin.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentPinkFallback)
                    .frame(width: 44, height: 44)
                    .background(Color.accentPinkFallback.opacity(0.1))
                    .clipShape(Circle())

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
                        openInMaps(location)
                    } label: {
                        Text("Directions")
                            .font(GatherFont.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.accentPinkFallback)
                            .clipShape(Capsule())
                    }
                }
            }

            if location.hasCoordinates, let lat = location.latitude, let lon = location.longitude {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker(location.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .disabled(true)
            }
        }
        .padding()
        .glassCard()
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

    // MARK: - Upcoming Functions Section

    private var upcomingFunctionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Functions")
                    .font(GatherFont.headline)

                Spacer()

                Text("\(event.functions.count) events")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            VStack(spacing: Spacing.sm) {
                ForEach(event.functions.sorted { $0.date < $1.date }.prefix(3)) { function in
                    FunctionTimelineCard(function: function)
                }

                if event.functions.count > 3 {
                    Text("+ \(event.functions.count - 3) more")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.accentPurpleFallback)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    // MARK: - Who's Going Section

    private var whosGoingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Who's Going")
                .font(GatherFont.headline)

            let attendingGuests = event.guests.filter { $0.status == .attending }
            let guestNames = attendingGuests.map { guest -> String in
                if isHost || event.privacy != .publicEvent {
                    return guest.name
                } else {
                    // Public event privacy: show first names only
                    return guest.name.components(separatedBy: " ").first ?? guest.name
                }
            }

            HStack(spacing: Spacing.sm) {
                AvatarStack(
                    names: attendingGuests.map { $0.name },
                    maxDisplay: 5,
                    size: AvatarSize.md
                )

                AttendeePreviewText(
                    names: guestNames,
                    totalCount: attendingGuests.count
                )

                Spacer()
            }
            .padding(Spacing.md)
            .glassCard()
        }
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Recent RSVPs")
                .font(GatherFont.headline)

            let recentGuests = event.guests
                .filter { $0.status == .attending }
                .prefix(5)

            if recentGuests.isEmpty {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(Color.gatherSecondaryText)
                    Text("No RSVPs yet")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .glassCard()
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(Array(recentGuests)) { guest in
                        RecentRSVPRow(guest: guest)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var maybeCount: Int {
        event.guests.filter { $0.status == .maybe }.count
    }

    private var declinedCount: Int {
        event.guests.filter { $0.status == .declined }.count
    }

    private var pendingCount: Int {
        event.guests.filter { $0.status == .pending }.count
    }

    private var totalAttending: Int {
        event.guests
            .filter { $0.status == .attending }
            .reduce(0) { $0 + 1 + $1.plusOneCount }
    }

    private var monthAbbreviation: String {
        GatherDateFormatter.monthAbbrev.string(from: event.startDate).uppercased()
    }

    private var dayNumber: String {
        GatherDateFormatter.dayNumber.string(from: event.startDate)
    }

    private var formattedFullDate: String {
        GatherDateFormatter.fullWeekdayDate.string(from: event.startDate)
    }

    private var formattedTime: String {
        var result = GatherDateFormatter.timeOnly.string(from: event.startDate)
        if let endDate = event.endDate {
            result += " - \(GatherDateFormatter.timeOnly.string(from: endDate))"
        }
        return result
    }

    private func openInMaps(_ location: EventLocation) {
        guard let lat = location.latitude, let lon = location.longitude else { return }
        guard let url = URL(string: "maps://?daddr=\(lat),\(lon)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(color)
                    .clipShape(Circle())

                Text(title)
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherPrimaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .glassCard()
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .pressEvents(
            onPress: { withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) { isPressed = true } },
            onRelease: { withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) { isPressed = false } }
        )
        .accessibilityLabel(title)
    }
}

// MARK: - RSVP Progress Row

struct RSVPProgressRow: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color
    let icon: String
    @State private var animatedProgress: Double = 0

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
                .frame(width: 70, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gatherTertiaryBackground)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * animatedProgress, height: 6)
                }
            }
            .frame(height: 6)

            Text("\(count)")
                .font(GatherFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.gatherPrimaryText)
                .frame(width: 30, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(count) of \(total)")
        .accessibilityValue("\(Int(percentage * 100)) percent")
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animatedProgress = percentage
            }
        }
    }
}

// MARK: - Function Timeline Card

struct FunctionTimelineCard: View {
    let function: EventFunction

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Timeline dot and line
            VStack(spacing: 0) {
                Circle()
                    .fill(function.date > Date() ? Color.accentPurpleFallback : Color.rsvpYesFallback)
                    .frame(width: 12, height: 12)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(function.name)
                    .font(GatherFont.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.gatherPrimaryText)

                HStack(spacing: Spacing.sm) {
                    Label(function.formattedDateShort, systemImage: "calendar")
                    if let location = function.location {
                        Label(location.name, systemImage: "mappin")
                            .lineLimit(1)
                    }
                }
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
            }

            Spacer()

            // RSVP count for this function
            let confirmedCount = function.invites.filter { $0.response == .yes }.count
            if confirmedCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "person.fill")
                    Text("\(confirmedCount)")
                }
                .font(GatherFont.caption)
                .foregroundStyle(Color.rsvpYesFallback)
            }
        }
        .padding(Spacing.sm)
        .glassCard()
    }
}

// MARK: - Recent RSVP Row

struct RecentRSVPRow: View {
    let guest: Guest

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(avatarColor)
                .frame(width: 32, height: 32)
                .overlay {
                    Text(guest.name.prefix(1).uppercased())
                        .font(GatherFont.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }

            Text(guest.name)
                .font(GatherFont.callout)
                .foregroundStyle(Color.gatherPrimaryText)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.rsvpYesFallback)
                Text("Attending")
                    .foregroundStyle(Color.gatherSecondaryText)
                if guest.plusOneCount > 0 {
                    Text("+\(guest.plusOneCount)")
                        .foregroundStyle(Color.accentPurpleFallback)
                }
            }
            .font(GatherFont.caption)
        }
        .padding(Spacing.sm)
        .glassCard()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.accentPurpleFallback, .neonBlue, .mintGreen, .warmCoral, .accentPinkFallback, .softLavender]
        let index = abs(guest.name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - EventFunction Extension

extension EventFunction {
    var formattedDateShort: String {
        GatherDateFormatter.monthDayTime.string(from: date)
    }
}
