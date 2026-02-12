import SwiftUI
import SwiftData

struct GuestDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    let guest: Guest
    let event: Event

    // Form state — copied from guest on appear
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var role: GuestRole
    @State private var status: RSVPStatus
    @State private var mealChoice: String
    @State private var dietaryRestrictions: String
    @State private var notes: String

    // Party member inline add
    @State private var newMemberName = ""
    @State private var newMemberRelationship: PartyRelationship = .spouse

    // UI state
    @State private var showRemoveConfirmation = false
    @State private var hasChanges = false

    init(guest: Guest, event: Event) {
        self.guest = guest
        self.event = event
        _name = State(initialValue: guest.name)
        _email = State(initialValue: guest.email ?? "")
        _phone = State(initialValue: guest.phone ?? "")
        _role = State(initialValue: guest.role)
        _status = State(initialValue: guest.status)
        _mealChoice = State(initialValue: guest.metadata?.mealChoice ?? "")
        _dietaryRestrictions = State(initialValue: guest.metadata?.dietaryRestrictions ?? "")
        _notes = State(initialValue: guest.metadata?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    avatarHeader
                    guestInfoSection
                    rsvpStatusSection
                    partyMembersSection
                    dietarySection

                    if !event.functions.isEmpty {
                        functionInvitesSection
                    }

                    dangerZone
                }
                .padding()
                .padding(.bottom, 40)
            }
            .background(Color.gatherBackground)
            .navigationTitle("Guest Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentPurpleFallback)
                }
            }
            .alert("Remove Guest", isPresented: $showRemoveConfirmation) {
                Button("Remove", role: .destructive) { removeGuest() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to remove \(guest.name) from this event? This action cannot be undone.")
            }
        }
    }

    // MARK: - Avatar Header

    private var avatarHeader: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(Color.forRSVPStatus(status), lineWidth: 3)
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(avatarColor)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Text(name.prefix(1).uppercased())
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
            }

            Text(name)
                .font(GatherFont.title2)
                .foregroundStyle(Color.gatherPrimaryText)

            HStack(spacing: Spacing.xs) {
                StatusBadge(status: status)

                if guest.totalHeadcount > 1 {
                    Text("Party of \(guest.totalHeadcount)")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Guest Info Section

    private var guestInfoSection: some View {
        FormSection(title: "Guest Info", icon: "person.text.rectangle") {
            VStack(spacing: Spacing.md) {
                formField(label: "Name", text: $name, placeholder: "Full name")
                formField(label: "Email", text: $email, placeholder: "email@example.com", keyboardType: .emailAddress)
                formField(label: "Phone", text: $phone, placeholder: "+1 555-0100", keyboardType: .phonePad)

                // Role picker
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Role")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)

                    HStack(spacing: Spacing.sm) {
                        ForEach(GuestRole.allCases, id: \.self) { guestRole in
                            Button {
                                role = guestRole
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: guestRole.icon)
                                        .font(.caption)
                                    Text(guestRole.displayName)
                                        .font(GatherFont.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(role == guestRole ? .white : Color.gatherPrimaryText)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(role == guestRole ? Color.accentPurpleFallback : Color.gatherSecondaryBackground)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - RSVP Status Section

    private var rsvpStatusSection: some View {
        FormSection(title: "RSVP Status", icon: "envelope.open") {
            HStack(spacing: Spacing.sm) {
                ForEach([RSVPStatus.attending, .maybe, .declined, .pending], id: \.self) { rsvpStatus in
                    Button {
                        status = rsvpStatus
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: rsvpStatus.icon)
                                .font(.title3)
                            Text(rsvpStatus.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .foregroundStyle(status == rsvpStatus ? .white : Color.forRSVPStatus(rsvpStatus))
                        .background(status == rsvpStatus ? Color.forRSVPStatus(rsvpStatus) : Color.forRSVPStatus(rsvpStatus).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                }
            }
        }
    }

    // MARK: - Party Members Section

    private var partyMembersSection: some View {
        FormSection(title: "Party Members", icon: "person.3") {
            VStack(spacing: Spacing.sm) {
                if guest.partyMembers.isEmpty && newMemberName.isEmpty {
                    Text("No party members yet")
                        .font(GatherFont.body)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Spacing.xs)
                }

                ForEach(guest.partyMembers.sorted { $0.createdAt < $1.createdAt }) { member in
                    partyMemberRow(member)
                }

                // Inline add form
                VStack(spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        TextField("Name", text: $newMemberName)
                            .font(GatherFont.body)
                            .padding(Spacing.sm)
                            .background(Color.gatherBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                        Picker("", selection: $newMemberRelationship) {
                            ForEach(PartyRelationship.allCases, id: \.self) { rel in
                                Text(rel.displayName).tag(rel)
                            }
                        }
                        .tint(Color.accentPurpleFallback)
                    }

                    if !newMemberName.isEmpty {
                        Button {
                            addPartyMember()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add \(newMemberName)")
                            }
                            .font(GatherFont.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.accentPurpleFallback)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                        }
                    }
                }
            }
        }
    }

    private func partyMemberRow(_ member: PartyMember) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(Color.accentPurpleFallback.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: member.relationship?.icon ?? "person")
                        .font(.caption)
                        .foregroundStyle(Color.accentPurpleFallback)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherPrimaryText)

                if let rel = member.relationship {
                    Text(rel.displayName)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }

            Spacer()

            if let dietary = member.dietaryRestrictions, !dietary.isEmpty {
                Text(dietary)
                    .font(.caption2)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(Capsule())
            }

            Button {
                removePartyMember(member)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(Color.rsvpNoFallback.opacity(0.7))
            }
            .accessibilityLabel("Remove party member")
        }
        .padding(Spacing.sm)
        .background(Color.gatherBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
    }

    // MARK: - Dietary & Preferences Section

    private var dietarySection: some View {
        FormSection(title: "Dietary & Notes", icon: "fork.knife") {
            VStack(spacing: Spacing.md) {
                formField(label: "Meal Choice", text: $mealChoice, placeholder: "e.g. Vegetarian, Chicken...")
                formField(label: "Dietary Restrictions", text: $dietaryRestrictions, placeholder: "e.g. Gluten-free, Nut allergy...")

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Notes")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)

                    TextField("Any additional notes...", text: $notes, axis: .vertical)
                        .font(GatherFont.body)
                        .lineLimit(3...6)
                        .padding(Spacing.sm)
                        .background(Color.gatherBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                }
            }
        }
    }

    // MARK: - Function Invites Section

    private var functionInvitesSection: some View {
        FormSection(title: "Function Invites", icon: "list.clipboard") {
            VStack(spacing: Spacing.sm) {
                ForEach(event.functions.sorted { $0.date < $1.date }) { function in
                    functionInviteRow(function)
                }
            }
        }
    }

    private func functionInviteRow(_ function: EventFunction) -> some View {
        let invite = function.invites.first { $0.guestId == guest.id }

        return HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(function.name)
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text(function.date, style: .date)
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            Spacer()

            if let invite = invite {
                HStack(spacing: 4) {
                    switch invite.inviteStatus {
                    case .notSent:
                        Label("Not Sent", systemImage: "clock")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                    case .sent:
                        Label("Sent", systemImage: "paperplane.fill")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.neonBlue)
                    case .responded:
                        if let response = invite.response {
                            Label(responseText(response), systemImage: responseIcon(response))
                                .font(GatherFont.caption)
                                .foregroundStyle(responseColor(response))
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.gatherSecondaryBackground)
                .clipShape(Capsule())
            } else {
                Text("Not invited")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
        }
        .padding(Spacing.sm)
        .background(Color.gatherBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                showRemoveConfirmation = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "person.badge.minus")
                    Text("Remove Guest")
                }
                .font(GatherFont.callout)
                .fontWeight(.medium)
                .foregroundStyle(Color.rsvpNoFallback)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.rsvpNoFallback.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
        }
    }

    // MARK: - Helpers

    private func formField(label: String, text: Binding<String>, placeholder: String, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)

            TextField(placeholder, text: text)
                .font(GatherFont.body)
                .keyboardType(keyboardType)
                .textContentType(contentType(for: label))
                .padding(Spacing.sm)
                .background(Color.gatherBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        }
    }

    private func contentType(for label: String) -> UITextContentType? {
        switch label {
        case "Name": return .name
        case "Email": return .emailAddress
        case "Phone": return .telephoneNumber
        default: return nil
        }
    }

    private func saveChanges() {
        guest.name = name
        guest.email = email.isEmpty ? nil : email
        guest.phone = phone.isEmpty ? nil : phone
        guest.role = role

        if guest.status != status {
            guest.status = status
            if status != .pending {
                guest.respondedAt = Date()
            }
        }

        let metadata = GuestMetadata(
            mealChoice: mealChoice.isEmpty ? nil : mealChoice,
            dietaryRestrictions: dietaryRestrictions.isEmpty ? nil : dietaryRestrictions,
            notes: notes.isEmpty ? nil : notes,
            assignedTasks: guest.metadata?.assignedTasks
        )
        guest.metadata = metadata

        modelContext.safeSave()
        dismiss()
    }

    private func addPartyMember() {
        let member = PartyMember(
            name: newMemberName.trimmingCharacters(in: .whitespaces),
            relationship: newMemberRelationship
        )
        guest.partyMembers.append(member)
        newMemberName = ""
        newMemberRelationship = .spouse
        modelContext.safeSave()
    }

    private func removePartyMember(_ member: PartyMember) {
        guest.partyMembers.removeAll { $0.id == member.id }
        modelContext.delete(member)
        modelContext.safeSave()
    }

    private func removeGuest() {
        event.guests.removeAll { $0.id == guest.id }
        // Remove related function invites
        for function in event.functions {
            function.invites.removeAll { $0.guestId == guest.id }
        }
        modelContext.delete(guest)
        modelContext.safeSave()
        dismiss()
    }

    private func responseText(_ response: RSVPResponse) -> String {
        switch response {
        case .yes: return "Going"
        case .no: return "Declined"
        case .maybe: return "Maybe"
        }
    }

    private func responseIcon(_ response: RSVPResponse) -> String {
        switch response {
        case .yes: return "checkmark.circle.fill"
        case .no: return "xmark.circle.fill"
        case .maybe: return "questionmark.circle.fill"
        }
    }

    private func responseColor(_ response: RSVPResponse) -> Color {
        switch response {
        case .yes: return .rsvpYesFallback
        case .no: return .rsvpNoFallback
        case .maybe: return .rsvpMaybeFallback
        }
    }

    private var avatarColor: Color {
        let colors: [Color] = [.accentPurpleFallback, .neonBlue, .rsvpYesFallback, .rsvpMaybeFallback, .accentPinkFallback, .mintGreen]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}
