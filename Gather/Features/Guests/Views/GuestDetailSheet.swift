import SwiftUI
import SwiftData

struct GuestDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    let guest: Guest
    let event: Event
    /// Hosts get the full edit form; non-hosts get a read-only view with no
    /// Save, no status switcher, and no danger zone.
    let isHost: Bool

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
    @State private var showDiscardConfirmation = false
    @State private var memberPendingRemoval: PartyMember?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespaces)
    }

    private var trimmedPhone: String {
        phone.trimmingCharacters(in: .whitespaces)
    }

    /// Same rule as AddGuestSheet so the edit path can't store an address
    /// the add path would have rejected.
    private var isEmailValid: Bool {
        trimmedEmail.isEmpty ||
        (trimmedEmail.contains("@") && trimmedEmail.split(separator: "@").last?.contains(".") == true)
    }

    /// Any staged edit that Save would persist — used to guard against
    /// silently discarding changes on swipe-down or Cancel.
    private var isDirty: Bool {
        trimmedName != guest.name ||
        (trimmedEmail.isEmpty ? nil : trimmedEmail) != guest.email ||
        (trimmedPhone.isEmpty ? nil : trimmedPhone) != guest.phone ||
        role != guest.role ||
        status != guest.status ||
        mealChoice != (guest.metadata?.mealChoice ?? "") ||
        dietaryRestrictions != (guest.metadata?.dietaryRestrictions ?? "") ||
        notes != (guest.metadata?.notes ?? "")
    }

    init(guest: Guest, event: Event, isHost: Bool = true) {
        self.guest = guest
        self.event = event
        self.isHost = isHost
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
                    if isHost {
                        rsvpStatusSection
                    }
                    partyMembersSection
                    dietarySection

                    if !event.functions.isEmpty {
                        functionInvitesSection
                    }

                    if isHost {
                        dangerZone
                    }
                }
                .padding(.vertical, Spacing.md)
                .horizontalPadding()
                .padding(.bottom, 40)
            }
            .background(Color.gatherBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Guest Details")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isHost && isDirty)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isHost ? "Cancel" : "Done") {
                        if isHost && isDirty {
                            showDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                if isHost {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveChanges() }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentPurpleFallback)
                            .disabled(trimmedName.isEmpty || !isEmailValid)
                    }
                }
            }
            .alert("Remove Guest", isPresented: $showRemoveConfirmation) {
                Button("Remove", role: .destructive) { removeGuest() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to remove \(guest.name) from this event? This action cannot be undone.")
            }
            .alert(
                "Remove Party Member",
                isPresented: Binding(
                    get: { memberPendingRemoval != nil },
                    set: { if !$0 { memberPendingRemoval = nil } }
                )
            ) {
                Button("Remove", role: .destructive) {
                    if let member = memberPendingRemoval {
                        removePartyMember(member)
                    }
                    memberPendingRemoval = nil
                }
                Button("Cancel", role: .cancel) { memberPendingRemoval = nil }
            } message: {
                Text("Remove \(memberPendingRemoval?.name ?? "this member") from \(guest.name)'s party?")
            }
            .confirmationDialog(
                "Discard changes?",
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) { }
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
        GuestDetailSection(title: "Guest Info", icon: "person.text.rectangle") {
            VStack(spacing: Spacing.md) {
                formField(label: "Name", text: $name, placeholder: "Full name")
                formField(label: "Email", text: $email, placeholder: "email@example.com", keyboardType: .emailAddress)

                if isHost && !isEmailValid {
                    Text("Enter a valid email address")
                        .font(.caption2)
                        .foregroundStyle(Color.warmCoral)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }

                formField(label: "Phone", text: $phone, placeholder: "+1 555-0100", keyboardType: .phonePad)

                // Role picker (read-only badge for non-hosts)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Role")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)

                    if isHost {
                        HStack(spacing: Spacing.sm) {
                            ForEach(GuestRole.allCases, id: \.self) { guestRole in
                                Button {
                                    role = guestRole
                                } label: {
                                    rolePillLabel(guestRole, isSelected: role == guestRole)
                                        // Compact pill, full-height hit area.
                                        .frame(minHeight: Layout.minTouchTarget)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(role == guestRole ? [.isSelected] : [])
                            }
                        }
                    } else {
                        rolePillLabel(role, isSelected: true)
                    }
                }
            }
        }
    }

    private func rolePillLabel(_ guestRole: GuestRole, isSelected: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: guestRole.icon)
                .font(.caption)
            Text(guestRole.displayName)
                .font(GatherFont.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(isSelected ? Color.accentPurpleFallback : Color.gatherTertiaryBackground)
        .clipShape(Capsule())
    }

    // MARK: - RSVP Status Section

    private var rsvpStatusSection: some View {
        GuestDetailSection(title: "RSVP Status", icon: "envelope.open") {
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
                        .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
                        .padding(.vertical, Spacing.sm)
                        .foregroundStyle(status == rsvpStatus ? .white : Color.forRSVPStatus(rsvpStatus))
                        .background(status == rsvpStatus ? Color.forRSVPStatus(rsvpStatus) : Color.forRSVPStatus(rsvpStatus).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                    .accessibilityAddTraits(status == rsvpStatus ? [.isSelected] : [])
                }
            }
        }
    }

    // MARK: - Party Members Section

    private var partyMembersSection: some View {
        GuestDetailSection(title: "Party Members", icon: "person.3") {
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

                if isHost {
                    partyMemberAddForm
                }
            }
        }
    }

    /// Inline add form — hosts only.
    private var partyMemberAddForm: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                TextField("Name", text: $newMemberName)
                    .font(GatherFont.body)
                    .padding(Spacing.sm)
                    .background(Color.gatherTertiaryBackground)
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

            if isHost {
                Button {
                    HapticService.warning()
                    memberPendingRemoval = member
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(Color.rsvpNoFallback.opacity(0.7))
                        .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Remove party member \(member.name)")
            }
        }
        .padding(Spacing.sm)
        .background(Color.gatherTertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
    }

    // MARK: - Dietary & Preferences Section

    private var dietarySection: some View {
        GuestDetailSection(title: "Dietary & Notes", icon: "fork.knife") {
            VStack(spacing: Spacing.md) {
                formField(label: "Meal Choice", text: $mealChoice, placeholder: "e.g. Vegetarian, Chicken...")
                formField(label: "Dietary Restrictions", text: $dietaryRestrictions, placeholder: "e.g. Gluten-free, Nut allergy...")

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Notes")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)

                    if isHost {
                        TextField("Any additional notes...", text: $notes, axis: .vertical)
                            .font(GatherFont.body)
                            .lineLimit(3...6)
                            .padding(Spacing.sm)
                            .background(Color.gatherTertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    } else {
                        Text(notes.isEmpty ? "—" : notes)
                            .font(GatherFont.body)
                            .foregroundStyle(notes.isEmpty ? Color.gatherSecondaryText : Color.gatherPrimaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.sm)
                            .background(Color.gatherTertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                }
            }
        }
    }

    // MARK: - Function Invites Section

    private var functionInvitesSection: some View {
        GuestDetailSection(title: "Function Invites", icon: "list.clipboard") {
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
        .background(Color.gatherTertiaryBackground)
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
                .foregroundStyle(Color.gatherError)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.gatherError.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Helpers

    /// Editable field for hosts; a plain read-only row for everyone else.
    private func formField(label: String, text: Binding<String>, placeholder: String, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)

            if isHost {
                TextField(placeholder, text: text)
                    .font(GatherFont.body)
                    .keyboardType(keyboardType)
                    .textContentType(contentType(for: label))
                    .padding(Spacing.sm)
                    .background(Color.gatherTertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            } else {
                Text(text.wrappedValue.isEmpty ? "—" : text.wrappedValue)
                    .font(GatherFont.body)
                    .foregroundStyle(text.wrappedValue.isEmpty ? Color.gatherSecondaryText : Color.gatherPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(Color.gatherTertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            }
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
        guard !trimmedName.isEmpty, isEmailValid else { return }
        guest.name = trimmedName
        // Trim before storing — mirrors AddGuestSheet, so duplicate-detection
        // keys and invite sending stay reliable.
        guest.email = trimmedEmail.isEmpty ? nil : trimmedEmail
        guest.phone = trimmedPhone.isEmpty ? nil : trimmedPhone
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
        // Delete related function invites (not just unlink — avoids orphaned rows)
        for function in event.functions {
            let orphanedInvites = function.invites.filter { $0.guestId == guest.id }
            for invite in orphanedInvites {
                modelContext.delete(invite)
            }
            function.invites.removeAll { $0.guestId == guest.id }
        }
        // Also drop any cloud RSVP so this guest can't be re-created from an
        // orphaned rsvps doc on the next sync.
        FirestoreService.shared.deleteRSVP(eventId: event.id, guestId: guest.id)
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
        // Hash the stored name, not the editable field, so the avatar doesn't
        // recolour on every keystroke while editing.
        Color.gatherAvatarColor(for: guest.name)
    }
}

// MARK: - Form Section (solid surface)

private struct GuestDetailSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(Color.accentPurpleFallback)

                Text(title)
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
            }

            content
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}
