import SwiftUI
import MapKit
import EventKit

struct FunctionDetailSheet: View {
    @Bindable var function: EventFunction
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var showRSVPSheet = false
    @State private var showCalendarAlert = false
    @State private var calendarAlertMessage = ""

    // Edit state
    @State private var editName = ""
    @State private var editDescription = ""
    @State private var editDate = Date()
    @State private var editEndTime: Date?
    @State private var editLocationName = ""
    @State private var editLocationAddress = ""
    @State private var editDressCode: DressCode?
    @State private var editCustomDressCode = ""

    private var isHost: Bool {
        event.hostId == authManager.currentUser?.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if isEditing {
                        editingView
                    } else {
                        detailView
                    }
                }
                .horizontalPadding()
                .padding(.vertical)
                .padding(.bottom, isHost ? 0 : 80) // Extra padding for RSVP button
            }
            .safeAreaInset(edge: .bottom) {
                if !isHost && !isEditing {
                    rsvpButtonBar
                }
            }
            .navigationTitle(isEditing ? "Edit Function" : function.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Done") {
                        if isEditing {
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(editName.isEmpty)
                    } else if isHost {
                        // Edit/Delete are host-only; invitees just view + RSVP.
                        Menu {
                            Button {
                                loadEditState()
                                isEditing = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("Delete Function", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteFunction()
                }
            } message: {
                Text("Are you sure you want to delete \"\(function.name)\"? This will also delete all invites for this function.")
            }
            .sheet(isPresented: $showRSVPSheet) {
                FunctionRSVPSheet(function: function, event: event)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - RSVP Button Bar

    private var rsvpButtonBar: some View {
        Group {
            if let invite = currentUserInvite, invite.response != nil {
                // User has already responded - show status with manage button
                respondedStatusBar(invite: invite)
            } else {
                // Not responded yet
                standardRSVPBar
            }
        }
        // Floating bar over scrolling content — glass is intentional here.
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .shadow(color: .black.opacity(0.1), radius: 15, y: -6)
        )
    }

    // Status bar for users who have responded
    private func respondedStatusBar(invite: FunctionInvite) -> some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(responseColor(for: invite.response).opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: responseIcon(for: invite.response))
                        .font(.title3)
                        .foregroundStyle(responseColor(for: invite.response))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(responseText(for: invite.response))
                        .font(GatherFont.headline)
                        .foregroundStyle(responseColor(for: invite.response))

                    if let response = invite.response, response == .yes || response == .maybe {
                        Text("\(invite.partySize) \(invite.partySize == 1 ? "person" : "people")")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }
            }

            Spacer()

            // Modify button
            Button {
                showRSVPSheet = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "pencil")
                    Text("Modify")
                }
                .font(GatherFont.callout)
                .fontWeight(.medium)
                .foregroundStyle(Color.accentPurpleFallback)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.gatherSecondaryBackground)
                .clipShape(Capsule())
            }
        }
        .padding()
    }

    // Standard RSVP bar for users who haven't responded
    private var standardRSVPBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Your RSVP")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
                Text(currentRSVPStatus)
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
    }

    /// The current user's Guest record on this event, if one exists.
    private var currentGuest: Guest? {
        guard let currentUser = authManager.currentUser else { return nil }
        return event.guests.first(where: { $0.userId == currentUser.id })
    }

    private var currentUserInvite: FunctionInvite? {
        guard let guest = currentGuest else { return nil }
        return function.invites.first(where: { $0.guestId == guest.id })
    }

    private var currentRSVPStatus: String {
        if let invite = currentUserInvite {
            switch invite.response {
            case .yes: return "Attending"
            case .no: return "Declined"
            case .maybe: return "Maybe"
            case .none:
                return invite.inviteStatus == .sent ? "Pending" : "Not responded"
            }
        }
        return "Not invited"
    }

    private func responseColor(for response: RSVPResponse?) -> Color {
        switch response {
        case .yes: return .rsvpYesFallback
        case .no: return .rsvpNoFallback
        case .maybe: return .rsvpMaybeFallback
        case .none: return .gatherSecondaryText
        }
    }

    private func responseIcon(for response: RSVPResponse?) -> String {
        switch response {
        case .yes: return "checkmark.circle.fill"
        case .no: return "xmark.circle.fill"
        case .maybe: return "questionmark.circle.fill"
        case .none: return "clock"
        }
    }

    private func responseText(for response: RSVPResponse?) -> String {
        switch response {
        case .yes: return "Attending"
        case .no: return "Not Attending"
        case .maybe: return "Maybe"
        case .none: return "Pending"
        }
    }

    // MARK: - Detail View

    private var detailView: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Date & Time
            HStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.gatherTertiaryBackground)
                        .frame(width: 56, height: 56)

                    VStack(spacing: 0) {
                        Text(monthAbbreviation)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentPurpleFallback)
                        Text(dayNumber)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.accentPurpleFallback)
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
            }
            .padding()
            .surfaceCard()

            // Location
            if let location = function.location {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Label("Location", systemImage: "mappin.circle.fill")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.accentPinkFallback)

                    Text(location.name)
                        .font(GatherFont.body)
                        .foregroundStyle(Color.gatherPrimaryText)

                    if let address = location.address {
                        Text(address)
                            .font(GatherFont.callout)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }

                    if location.hasCoordinates, let lat = location.latitude, let lon = location.longitude {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))) {
                            Marker(location.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        }
                        .frame(height: Layout.photoHeight)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        .disabled(true)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .surfaceCard()
            }

            // Dress Code
            if let dressCode = function.displayDressCode {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Label("Dress Code", systemImage: "tshirt.fill")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.accentPurpleFallback)

                    Text(dressCode)
                        .font(GatherFont.body)
                        .foregroundStyle(Color.gatherPrimaryText)

                    if let code = function.dressCode, code != .custom {
                        Text(code.description)
                            .font(GatherFont.callout)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .surfaceCard()
            }

            // Description
            if let description = function.functionDescription, !description.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("About")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text(description)
                        .font(GatherFont.body)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .surfaceCard()
            }

            // Add to Calendar
            Button {
                Task {
                    calendarAlertMessage = await CalendarService.shared.addFunctionToCalendar(
                        function: function,
                        eventTitle: event.title
                    )
                    showCalendarAlert = true
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                        .foregroundStyle(Color.accentPurpleFallback)

                    Text("Add to Calendar")
                        .font(GatherFont.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.gatherPrimaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .padding()
                .surfaceCard()
            }
            .buttonStyle(.plain)

            // RSVP Summary
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Guest Responses")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)

                HStack(spacing: Spacing.lg) {
                    RSVPStatBox(count: function.attendingCount, label: "Attending", color: .rsvpYesFallback)
                    RSVPStatBox(count: function.maybeCount, label: "Maybe", color: .rsvpMaybeFallback)
                    RSVPStatBox(count: function.declinedCount, label: "Declined", color: .rsvpNoFallback)
                    RSVPStatBox(count: function.pendingCount, label: "Pending", color: .gatherSecondaryText)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard()

            // Per-function guest list — hosts pick who is invited to THIS
            // function, independent of the parent event's full guest list.
            if isHost {
                guestListSection
            }
        }
        .alert("Calendar", isPresented: $showCalendarAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calendarAlertMessage)
        }
    }

    // MARK: - Guest List (host-only)

    /// Guests sorted so already-invited people float to the top, then by name.
    private var sortedGuests: [Guest] {
        event.guests.sorted { lhs, rhs in
            let lInvited = isInvited(lhs)
            let rInvited = isInvited(rhs)
            if lInvited != rInvited { return lInvited }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// How many of the event's guests are invited to THIS function.
    private var invitedCount: Int {
        function.invites.count
    }

    private var guestListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header + live invited summary
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Guests")
                        .gatherSectionHeader()
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text(inviteSummaryText)
                        .gatherMetaText()
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                // Quick actions
                HStack(spacing: Spacing.xs) {
                    Button {
                        inviteAll()
                    } label: {
                        Text("Invite all")
                            .font(GatherFont.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentPurpleFallback)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            .background(Color.accentPurpleFallback.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(event.guests.isEmpty || invitedCount == event.guests.count)

                    Button {
                        clearInvites()
                    } label: {
                        Text("Clear")
                            .font(GatherFont.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.gatherError)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            .background(Color.gatherError.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(invitedCount == 0)
                }
            }

            if event.guests.isEmpty {
                Text("Add guests to the event first, then choose who's invited to this function.")
                    .gatherMetaText()
                    .foregroundStyle(Color.gatherTertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Spacing.sm)
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(sortedGuests, id: \.id) { guest in
                        FunctionGuestRow(
                            guest: guest,
                            isInvited: isInvited(guest),
                            response: response(for: guest),
                            onToggle: { toggleInvite(for: guest) },
                            isSent: isInviteSent(guest),
                            availableChannels: InviteService.shared.availableChannels(for: guest),
                            onSend: { channel in sendInvite(to: guest, via: channel) }
                        )
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }

    /// Per-function RSVP breakdown of the people actually invited here.
    private var inviteSummaryText: String {
        let going = function.invites.filter { $0.response == .yes }.count
        let maybe = function.invites.filter { $0.response == .maybe }.count
        return "\(invitedCount) invited · \(going) going · \(maybe) maybe"
    }

    private func isInvited(_ guest: Guest) -> Bool {
        function.invites.contains { $0.guestId == guest.id }
    }

    private func response(for guest: Guest) -> RSVPResponse? {
        function.invites.first { $0.guestId == guest.id }?.response
    }

    private func isInviteSent(_ guest: Guest) -> Bool {
        guard let invite = function.invites.first(where: { $0.guestId == guest.id }) else { return false }
        return invite.inviteStatus != .notSent
    }

    /// Sends one guest their unique invite link for THIS function over the chosen
    /// channel and records the invite as sent.
    private func sendInvite(to guest: Guest, via channel: InviteChannel) {
        guard let invite = function.invites.first(where: { $0.guestId == guest.id }) else { return }
        let sent = InviteService.shared.sendFunctionInvite(guest: guest, event: event, function: function, via: channel)
        if sent {
            InviteService.shared.markInviteSent(invite: invite, channel: channel, modelContext: modelContext)
            function.updatedAt = Date()
            modelContext.safeSave()
            HapticService.success()
        }
    }

    /// Toggling ON creates a FunctionInvite for this guest+function; toggling
    /// OFF removes it from the relationship and deletes the record.
    private func toggleInvite(for guest: Guest) {
        if let existing = function.invites.first(where: { $0.guestId == guest.id }) {
            function.invites.removeAll { $0.id == existing.id }
            modelContext.delete(existing)
            HapticService.selection()
        } else {
            let invite = FunctionInvite(guestId: guest.id, functionId: function.id)
            function.invites.append(invite)
            HapticService.selection()
        }
        function.updatedAt = Date()
        modelContext.safeSave()
    }

    private func inviteAll() {
        for guest in event.guests where !isInvited(guest) {
            let invite = FunctionInvite(guestId: guest.id, functionId: function.id)
            function.invites.append(invite)
        }
        function.updatedAt = Date()
        modelContext.safeSave()
        HapticService.success()
    }

    /// Removes every invite for this function. Guests who already responded
    /// lose their per-function RSVP too — that's the intended "start over".
    private func clearInvites() {
        for invite in function.invites {
            modelContext.delete(invite)
        }
        function.invites.removeAll()
        function.updatedAt = Date()
        modelContext.safeSave()
        HapticService.mediumImpact()
    }

    // MARK: - Editing View

    private var editingView: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Name
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Name")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)

                TextField("Function Name", text: $editName)
                    .font(GatherFont.body)
                    .padding()
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }

            // Description
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Description")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)

                TextField("Description", text: $editDescription, axis: .vertical)
                    .font(GatherFont.body)
                    .lineLimit(3...6)
                    .padding()
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }

            // Date & Time
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Date & Time")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)

                DatePicker("Start", selection: $editDate)
                    .font(GatherFont.body)

                if editEndTime != nil {
                    DatePicker("End", selection: Binding(
                        get: { editEndTime ?? Date() },
                        set: { editEndTime = $0 }
                    ), displayedComponents: .hourAndMinute)
                    .font(GatherFont.body)

                    Button("Remove End Time") {
                        editEndTime = nil
                    }
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherError)
                } else {
                    Button("Add End Time") {
                        editEndTime = editDate.addingTimeInterval(3600 * 4)
                    }
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.accentPurpleFallback)
                }
            }

            // Location
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Location")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)

                TextField("Venue Name", text: $editLocationName)
                    .font(GatherFont.body)
                    .padding()
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

                TextField("Address (optional)", text: $editLocationAddress)
                    .font(GatherFont.body)
                    .padding()
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }

            // Dress Code
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Dress Code")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)

                Picker("Dress Code", selection: $editDressCode) {
                    Text("None").tag(nil as DressCode?)
                    ForEach(DressCode.allCases, id: \.self) { code in
                        Text(code.displayName).tag(code as DressCode?)
                    }
                }
                .pickerStyle(.segmented)

                if editDressCode == .custom {
                    TextField("Custom Dress Code", text: $editCustomDressCode)
                        .font(GatherFont.body)
                        .padding()
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
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

    private var formattedFullDate: String {
        GatherDateFormatter.fullWeekdayDateYear.string(from: function.date)
    }

    private var formattedTime: String {
        var result = GatherDateFormatter.timeOnly.string(from: function.date)
        if let endTime = function.endTime {
            result += " - \(GatherDateFormatter.timeOnly.string(from: endTime))"
        }
        return result
    }

    private func loadEditState() {
        editName = function.name
        editDescription = function.functionDescription ?? ""
        editDate = function.date
        editEndTime = function.endTime
        editLocationName = function.location?.name ?? ""
        editLocationAddress = function.location?.address ?? ""
        editDressCode = function.dressCode
        editCustomDressCode = function.customDressCode ?? ""
    }

    private func saveChanges() {
        function.name = editName
        function.functionDescription = editDescription.isEmpty ? nil : editDescription
        function.date = editDate
        function.endTime = editEndTime
        if editLocationName.isEmpty {
            function.location = nil
        } else {
            // Preserve the existing map pin (coordinates/city/state/country) — the
            // edit form only exposes name + address, so rebuilding from scratch
            // would silently drop the geocoded location.
            var loc = function.location ?? EventLocation(name: editLocationName)
            loc.name = editLocationName
            loc.address = editLocationAddress.isEmpty ? nil : editLocationAddress
            function.location = loc
        }
        function.dressCode = editDressCode
        function.customDressCode = editDressCode == .custom ? editCustomDressCode : nil
        function.updatedAt = Date()

        modelContext.safeSave()
        isEditing = false
    }

    private func deleteFunction() {
        if let index = event.functions.firstIndex(where: { $0.id == function.id }) {
            event.functions.remove(at: index)
            modelContext.delete(function)
            modelContext.safeSave()
        }
        dismiss()
    }
}

// MARK: - RSVP Stat Box

struct RSVPStatBox: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text("\(count)")
                .font(GatherFont.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
    }
}

// MARK: - Function Guest Row

/// One guest row in the per-function guest list: avatar initials, name, live
/// per-function RSVP badge, and an invite toggle.
struct FunctionGuestRow: View {
    let guest: Guest
    let isInvited: Bool
    let response: RSVPResponse?
    let onToggle: () -> Void
    var isSent: Bool = false
    var availableChannels: [InviteChannel] = []
    var onSend: ((InviteChannel) -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Initials avatar
            ZStack {
                Circle()
                    .fill(Color.gatherElevated)
                    .frame(width: 36, height: 36)
                Text(initials)
                    .font(GatherFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(guest.name)
                    .gatherRowTitle()
                    .foregroundStyle(Color.gatherPrimaryText)
                    .lineLimit(1)

                if isInvited {
                    Text(responseLabel)
                        .font(GatherFont.caption)
                        .foregroundStyle(responseColor)
                }
            }

            Spacer()

            // Per-guest send: each invited guest gets their OWN unique function
            // invite link over the chosen channel.
            if isInvited, let onSend, !availableChannels.isEmpty {
                Menu {
                    ForEach(availableChannels, id: \.self) { channel in
                        Button {
                            onSend(channel)
                        } label: {
                            Label(channel.displayName, systemImage: channelIcon(channel))
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isSent ? "checkmark.circle.fill" : "paperplane.fill")
                        Text(isSent ? "Sent" : "Send")
                            .font(GatherFont.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(isSent ? Color.rsvpYesFallback : Color.accentPurpleFallback)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((isSent ? Color.rsvpYesFallback : Color.accentPurpleFallback).opacity(0.12), in: Capsule())
                }
                .accessibilityLabel(isSent ? "Resend invite to \(guest.name)" : "Send invite to \(guest.name)")
            }

            Toggle("", isOn: Binding(
                get: { isInvited },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(Color.accentPurpleFallback)
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(Color.gatherElevated.opacity(isInvited ? 0.6 : 0))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(guest.name), \(isInvited ? "invited to this function" : "not invited")")
        .accessibilityAddTraits(.isButton)
    }

    private func channelIcon(_ channel: InviteChannel) -> String {
        switch channel {
        case .whatsapp: return "bubble.left.and.bubble.right.fill"
        case .sms: return "message.fill"
        case .email: return "envelope.fill"
        case .copied, .inAppLink: return "doc.on.doc.fill"
        }
    }

    private var initials: String {
        let parts = guest.name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? (parts.last?.first.map(String.init) ?? "") : ""
        let result = (first + last).uppercased()
        return result.isEmpty ? "?" : result
    }

    private var responseLabel: String {
        switch response {
        case .yes: return "Going"
        case .maybe: return "Maybe"
        case .no: return "Can't make it"
        case .none: return "Invited · no response yet"
        }
    }

    private var responseColor: Color {
        switch response {
        case .yes: return .rsvpYesFallback
        case .maybe: return .rsvpMaybeFallback
        case .no: return .rsvpNoFallback
        case .none: return .gatherSecondaryText
        }
    }
}

// MARK: - Preview

#Preview {
    let function = EventFunction(
        name: "Sangeet",
        functionDescription: "A night of music, dance, and celebration!",
        date: Date().addingTimeInterval(86400 * 3),
        endTime: Date().addingTimeInterval(86400 * 3 + 14400),
        location: EventLocation(name: "Grand Ballroom", address: "123 Main St"),
        dressCode: .traditional,
        eventId: UUID()
    )
    let event = Event(title: "Wedding", startDate: Date())

    FunctionDetailSheet(function: function, event: event)
}
