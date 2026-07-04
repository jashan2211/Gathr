import SwiftUI
import MapKit
import EventKit

struct OverviewTab: View {
    @Bindable var event: Event
    @Binding var showGuestList: Bool
    @Binding var showRSVPSheet: Bool
    /// Jumps the parent detail view to the Functions tab (EventDetailView
    /// owns the tab selection). Defaults to a no-op for previews.
    var onShowFunctions: () -> Void = {}
    @EnvironmentObject var authManager: AuthManager
    @State private var showSendInvites = false
    @State private var showAddGuest = false
    @State private var showCalendarAlert = false
    @State private var calendarAlertMessage = ""
    @State private var isAddingToCalendar = false
    @State private var showShareSheet = false

    var body: some View {
        // No ScrollView here — EventDetailView owns the single page scroll
        // (hero scrolls away, tab bar pins). This tab renders content only.
        Group {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Quick Actions (for hosts)
                if isHost {
                    quickActionsSection
                }

                // RSVP Summary Card — host analytics; guests get Who's Going below.
                if isHost {
                    rsvpSummaryCard
                }

                // Function RSVP guidance banner (for non-host users on function-based events)
                if !event.functions.isEmpty && !isHost {
                    Button {
                        HapticService.buttonTap()
                        onShowFunctions()
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(Color.accentPurpleFallback)
                            Text("RSVP to individual functions on the Functions tab")
                                .font(GatherFont.caption)
                                .foregroundStyle(Color.gatherSecondaryText)
                            Spacer(minLength: Spacing.xs)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(Color.accentPurpleFallback)
                        }
                        .padding(Spacing.sm)
                        .frame(minHeight: Layout.minTouchTarget)
                        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
                        .surfaceCard()
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the Functions tab")
                }

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
        .alert("Add to Calendar", isPresented: $showCalendarAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calendarAlertMessage)
        }
        .sheet(isPresented: $showShareSheet) {
            // Same rich share sheet as the toolbar action — one share path
            // everywhere (event preview, Message/Email/More, copy link).
            ShareSheet(event: event)
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
        // One compact 44pt row of capsule chips — all three host actions stay
        // one tap away without eating the top band of the Overview. Chips
        // share the event's category accent so the screen keeps one color
        // story instead of a rainbow of unrelated tints.
        HStack(spacing: Spacing.sm) {
            QuickActionChip(
                icon: "person.badge.plus",
                title: "Add Guest",
                color: Color.forCategory(event.category)
            ) {
                showAddGuest = true
            }
            .bouncyAppear(delay: 0)

            QuickActionChip(
                icon: "paperplane.fill",
                title: "Invites",
                color: Color.forCategory(event.category)
            ) {
                showSendInvites = true
            }
            .bouncyAppear(delay: 0.05)

            QuickActionChip(
                icon: "square.and.arrow.up",
                title: "Share",
                color: Color.forCategory(event.category)
            ) {
                showShareSheet = true
            }
            // Long-press shortcut: grab the invite link without opening the
            // share sheet — handy when pasting straight into a group chat.
            .contextMenu {
                Button {
                    // The universal link works for anyone — app or browser.
                    if let link = InviteService.shared.generateShareableLink(event: event) {
                        UIPasteboard.general.string = link.absoluteString
                        HapticService.success()
                    }
                } label: {
                    Label("Copy Invite Link", systemImage: "link")
                }
            }
            .bouncyAppear(delay: 0.1)
        }
    }

    // MARK: - RSVP Summary Card

    @ViewBuilder
    private var rsvpSummaryCard: some View {
        if event.guests.isEmpty {
            // Brand-new event: a nudge beats four all-zero progress bars.
            GatherEmptyState(
                icon: "envelope.open",
                title: "No guests yet",
                message: "Add guests to start collecting RSVPs.",
                accent: Color.forCategory(event.category),
                actionTitle: "Add Guest",
                action: { showAddGuest = true }
            )
            .frame(maxWidth: .infinity)
        } else {
            // Whole card opens the full, filterable guest roster.
            Button {
                HapticService.buttonTap()
                showGuestList = true
            } label: {
                rsvpSummaryContent
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the full guest list")
        }
    }

    private var rsvpSummaryContent: some View {
        VStack(spacing: Spacing.md) {
            // Header
            HStack {
                Text("Guest Summary")
                    .gatherSectionHeader()
                    .foregroundStyle(Color.gatherPrimaryText)

                Spacer()

                Text("\(event.guests.count) invited")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .contentTransition(.numericText())

                HStack(spacing: 2) {
                    Text("View all")
                        .font(GatherFont.caption)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(Color.accentPurpleFallback)
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
        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .surfaceCard()
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
                    .foregroundStyle(Color.onCategory(event.category))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.forCategory(event.category))

                Text(dayNumber)
                    .gatherSerifHeadline()
                    .foregroundStyle(Color.gatherPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
            }
            .frame(width: 56)
            .background(Color.gatherElevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(formattedFullDate)
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text(formattedTime)
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)

                // Compact countdown so "when" is answerable without math.
                // TimelineView re-renders each minute while visible so
                // "Happening now" actually appears without a manual Timer.
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    Text(countdownText)
                        .font(GatherFont.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.forCategory(event.category))
                }

                if let endDate = event.endDate, !Calendar.current.isDate(event.startDate, inSameDayAs: endDate) {
                    Text("Multi-day event")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.accentPurpleFallback)
                }
            }

            Spacer()

            Button {
                guard !isAddingToCalendar else { return }
                isAddingToCalendar = true
                Task {
                    calendarAlertMessage = await CalendarService.shared.addEventToCalendar(event: event)
                    HapticService.success()
                    showCalendarAlert = true
                    isAddingToCalendar = false
                }
            } label: {
                Group {
                    if isAddingToCalendar {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.accentPurpleFallback)
                    } else {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title2)
                            .foregroundStyle(Color.accentPurpleFallback)
                    }
                }
                .frame(width: 44, height: 44)
                .background(Color.gatherElevated)
                .clipShape(Circle())
            }
            .disabled(isAddingToCalendar)
            .accessibilityLabel("Add to calendar")
        }
        .padding()
        .surfaceCard()
    }

    // MARK: - Location Section

    @ViewBuilder
    private func locationSection(_ location: EventLocation) -> some View {
        if location.isVirtual {
            // Virtual events get the same one-tap card — straight into the
            // meeting link, with the "Join" capsule as the visual affordance.
            if let url = location.virtualURL {
                Button {
                    HapticService.buttonTap()
                    UIApplication.shared.open(url)
                } label: {
                    locationCardContent(location)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the meeting link")
            } else {
                locationCardContent(location)
            }
        } else {
            // Whole card is one tap target — a big, thumb-friendly hit area
            // that jumps straight to Apple Maps. The "Directions" capsule
            // stays as the visual affordance inside it.
            Button {
                HapticService.buttonTap()
                openInMaps(location)
            } label: {
                locationCardContent(location)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens directions in Apple Maps")
        }
    }

    private func locationCardContent(_ location: EventLocation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                Image(systemName: location.isVirtual ? "video.fill" : "mappin.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentPinkFallback)
                    .frame(width: 44, height: 44)
                    .background(Color.gatherElevated)
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
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.caption2)
                        Text("Directions")
                            .font(GatherFont.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.accentPinkFallback)
                    .clipShape(Capsule())
                } else if location.virtualURL != nil {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "video.fill")
                            .font(.caption2)
                        Text("Join")
                            .font(GatherFont.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.accentPurpleFallback)
                    .clipShape(Capsule())
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
                // Preview only — taps fall through to the card button, which
                // opens the real Maps app (no accidental pan-scroll fights).
                .allowsHitTesting(false)
            }
        }
        .padding()
        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .surfaceCard()
    }

    // MARK: - Description Section

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("About")
                .gatherSectionHeader()
                .foregroundStyle(Color.gatherPrimaryText)

            // Primary-content brightness + open leading — the description is
            // the event's actual story, not dim metadata.
            Text(description)
                .font(GatherFont.body)
                .foregroundStyle(Color.gatherPrimaryText.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Upcoming Functions Section

    private var upcomingFunctionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Functions")
                    .gatherSectionHeader()
                    .foregroundStyle(Color.gatherPrimaryText)

                Spacer()

                Text("\(event.functions.count) function\(event.functions.count == 1 ? "" : "s")")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            VStack(spacing: Spacing.sm) {
                ForEach(event.functions.sorted { $0.date < $1.date }.prefix(3)) { function in
                    FunctionTimelineCard(function: function)
                }

                if event.functions.count > 3 {
                    Button {
                        HapticService.buttonTap()
                        onShowFunctions()
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Text("+ \(event.functions.count - 3) more")
                                .font(GatherFont.caption)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(Color.accentPurpleFallback)
                        .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the Functions tab")
                }
            }
        }
    }

    // MARK: - Who's Going Section

    private var whosGoingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Who's Going")
                .gatherSectionHeader()
                .foregroundStyle(Color.gatherPrimaryText)

            let attendingGuests = event.guests.filter { $0.status == .attending }
            let guestNames = attendingGuests.map { guest -> String in
                if isHost || event.privacy != .publicEvent {
                    return guest.name
                } else {
                    // Public event privacy: show first names only
                    return guest.name.components(separatedBy: " ").first ?? guest.name
                }
            }

            // The card opens the full roster — the avatar stack is a preview,
            // not the whole story.
            Button {
                HapticService.buttonTap()
                showGuestList = true
            } label: {
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

                    HStack(spacing: 2) {
                        Text("View all")
                            .font(GatherFont.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.accentPurpleFallback)
                }
                .padding(Spacing.md)
                .contentShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
                .surfaceCard()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the full guest list")
        }
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Recent RSVPs")
                .gatherSectionHeader()
                .foregroundStyle(Color.gatherPrimaryText)

            let recentGuests = event.guests
                .filter { $0.status == .attending }
                .sorted { ($0.respondedAt ?? .distantPast) > ($1.respondedAt ?? .distantPast) }
                .prefix(5)

            if recentGuests.isEmpty {
                GatherEmptyState(
                    icon: "envelope.open",
                    title: "No RSVPs yet",
                    message: "As guests respond, their RSVPs will show up here.",
                    accent: Color.forCategory(event.category)
                )
                .frame(maxWidth: .infinity)
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

    /// Plain computed countdown — recomputed on each render, no timers.
    private var countdownText: String {
        let now = Date()
        if now < event.startDate {
            let interval = event.startDate.timeIntervalSince(now)
            if interval < 3600 {
                let minutes = max(1, Int(interval / 60))
                return "In \(minutes) minute\(minutes == 1 ? "" : "s")"
            } else if interval < 86400 {
                let hours = Int(interval / 3600)
                return "In \(hours) hour\(hours == 1 ? "" : "s")"
            } else {
                let calendar = Calendar.current
                let days = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: now),
                    to: calendar.startOfDay(for: event.startDate)
                ).day ?? 0
                return days == 1 ? "Tomorrow" : "In \(days) days"
            }
        }
        // Already started: still "now" until the end date — or, for
        // open-ended events, until the start day is over.
        let effectiveEnd = event.endDate
            ?? Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: event.startDate)
            ?? event.startDate
        return now <= effectiveEnd ? "Happening now" : "Ended"
    }

    /// Opens Apple Maps: precise pin when we have coordinates, otherwise a
    /// search query built from the venue name and address.
    private func openInMaps(_ location: EventLocation) {
        if let lat = location.latitude, let lon = location.longitude {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            mapItem.name = location.name
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
            ])
        } else {
            var parts: [String] = [location.name]
            if let address = location.address { parts.append(address) }
            if let city = location.city { parts.append(city) }
            let query = parts.joined(separator: ", ")
            guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://maps.apple.com/?q=\(encoded)") else { return }
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Quick Action Chip

/// A compact 44pt capsule chip (icon + label) for the host quick-action row —
/// replaces the old ~100pt QuickActionCard tiles so the Overview's top band
/// stays light while keeping every action one tap away.
struct QuickActionChip: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button {
            HapticService.buttonTap()
            action()
        } label: {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.sm, weight: .semibold))
                    .foregroundStyle(color)

                Text(title)
                    .gatherRowTitle()
                    .foregroundStyle(Color.gatherPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
            .contentShape(Capsule())
            .surfaceCard(cornerRadius: CornerRadius.full)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .pressEvents(
            onPress: { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = true } },
            onRelease: { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false } }
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

            // minWidth (not fixed width) so labels/counts survive Dynamic
            // Type and 4-digit guest counts without truncating.
            Text(label)
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 70, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gatherElevated)
                        .frame(height: 6)

                    // Fill is driven directly by the value: first render is
                    // instant (no replayed zero-to-full sweep on every tab
                    // switch); only real RSVP changes animate.
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 6)
                        .animation(.easeOut(duration: 0.5), value: percentage)
                }
            }
            .frame(height: 6)

            Text("\(count)")
                .font(GatherFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.gatherPrimaryText)
                .frame(minWidth: 30, alignment: .trailing)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(count) of \(total)")
        .accessibilityValue("\(Int(percentage * 100)) percent")
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
        .surfaceCard()
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
        .surfaceCard()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.accentPurpleFallback, .neonBlue, .mintGreen, .warmCoral, .accentPinkFallback, .softLavender]
        let index = guest.name.stableHash % colors.count
        return colors[index]
    }
}

// MARK: - EventFunction Extension

extension EventFunction {
    var formattedDateShort: String {
        GatherDateFormatter.monthDayTime.string(from: date)
    }
}
