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
                .padding()
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
                    } else {
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
        VStack(spacing: 0) {
            Divider()

            if let invite = currentUserInvite, invite.response != nil {
                // User has already responded - show status with manage button
                respondedStatusBar(invite: invite)
            } else {
                // Not responded yet
                standardRSVPBar
            }
        }
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
                .background(Color.accentPurpleFallback.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding()
        .background(.ultraThinMaterial)
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
        .background(.ultraThinMaterial)
    }

    private var currentUserInvite: FunctionInvite? {
        guard let currentUser = authManager.currentUser else { return nil }
        return function.invites.first(where: { $0.guestId == currentUser.id })
    }

    private var currentRSVPStatus: String {
        guard let currentUser = authManager.currentUser else {
            return "Not invited"
        }

        if let invite = function.invites.first(where: { $0.guestId == currentUser.id }) {
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
        case .yes: return .green
        case .no: return .red
        case .maybe: return .orange
        case .none: return .gray
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
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Date & Time
            HStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.accentPurpleFallback.opacity(0.1))
                        .frame(width: 56, height: 56)

                    VStack(spacing: 0) {
                        Text(monthAbbreviation)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentPurpleFallback)
                        Text(dayNumber)
                            .font(.title2)
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
            }

            // Location
            if let location = function.location {
                Divider()

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
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        .disabled(true)
                    }
                }
            }

            // Dress Code
            if let dressCode = function.displayDressCode {
                Divider()

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
            }

            // Description
            if let description = function.functionDescription, !description.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("About")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text(description)
                        .font(GatherFont.body)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }

            Divider()

            // Add to Calendar
            Button {
                CalendarService.shared.addFunctionToCalendar(
                    function: function,
                    eventTitle: event.title
                ) { message in
                    calendarAlertMessage = message
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
                .background(Color.accentPurpleFallback.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
            .buttonStyle(.plain)

            Divider()

            // RSVP Summary
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Guest Responses")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)

                HStack(spacing: Spacing.lg) {
                    RSVPStatBox(count: function.attendingCount, label: "Attending", color: .green)
                    RSVPStatBox(count: function.maybeCount, label: "Maybe", color: .orange)
                    RSVPStatBox(count: function.declinedCount, label: "Declined", color: .red)
                    RSVPStatBox(count: function.pendingCount, label: "Pending", color: .gray)
                }
            }
        }
        .alert("Calendar", isPresented: $showCalendarAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calendarAlertMessage)
        }
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
                    .foregroundStyle(.red)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: function.date).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: function.date)
    }

    private var formattedFullDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
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
        function.location = editLocationName.isEmpty ? nil : EventLocation(
            name: editLocationName,
            address: editLocationAddress.isEmpty ? nil : editLocationAddress
        )
        function.dressCode = editDressCode
        function.customDressCode = editDressCode == .custom ? editCustomDressCode : nil
        function.updatedAt = Date()

        try? modelContext.save()
        isEditing = false
    }

    private func deleteFunction() {
        if let index = event.functions.firstIndex(where: { $0.id == function.id }) {
            event.functions.remove(at: index)
            modelContext.delete(function)
            try? modelContext.save()
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
