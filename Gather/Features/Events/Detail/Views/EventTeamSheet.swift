import SwiftUI
import SwiftData

struct EventTeamSheet: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var members: [EventMember]
    @EnvironmentObject var authManager: AuthManager

    @State private var showAddMember = false
    @State private var showInviteLink = false
    @State private var selectedRole: EventRole = .manager
    @State private var copiedCode: String?

    init(event: Event) {
        self.event = event
        let eventId = event.id
        _members = Query(
            filter: #Predicate<EventMember> { $0.eventId == eventId }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                // Owner section
                Section("Owner") {
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(LinearGradient.gatherAccentGradient)
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text(authManager.currentUser?.name.prefix(1).uppercased() ?? "?")
                                    .font(GatherFont.callout)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(authManager.currentUser?.name ?? "You")
                                .font(GatherFont.callout)
                                .fontWeight(.medium)
                            Text("Owner · Full access")
                                .font(.caption2)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }

                        Spacer()

                        Image(systemName: "crown.fill")
                            .foregroundStyle(Color.rsvpMaybeFallback)
                    }
                }

                // Team members
                let activeMembers = members.filter { $0.inviteStatus == .accepted }
                if !activeMembers.isEmpty {
                    Section("Team (\(activeMembers.count))") {
                        ForEach(activeMembers) { member in
                            memberRow(member)
                        }
                    }
                }

                // Pending invites
                let pendingMembers = members.filter { $0.inviteStatus == .pending }
                if !pendingMembers.isEmpty {
                    Section("Pending Invites") {
                        ForEach(pendingMembers) { member in
                            memberRow(member, isPending: true)
                        }
                    }
                }

                // Add member
                Section {
                    Button {
                        showAddMember = true
                    } label: {
                        Label("Invite Team Member", systemImage: "person.badge.plus")
                            .foregroundStyle(Color.accentPurpleFallback)
                    }

                    Button {
                        showInviteLink = true
                    } label: {
                        Label("Share Invite Link", systemImage: "link")
                            .foregroundStyle(Color.accentPurpleFallback)
                    }
                }

                // Roles explained
                Section("Role Permissions") {
                    ForEach([EventRole.admin, .manager, .viewer], id: \.self) { role in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: role.icon)
                                .font(.callout)
                                .foregroundStyle(Color.accentPurpleFallback)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(role.rawValue)
                                    .font(GatherFont.callout)
                                    .fontWeight(.medium)
                                Text(role.description)
                                    .font(.caption2)
                                    .foregroundStyle(Color.gatherSecondaryText)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Event Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddMember) {
                AddMemberSheet(eventId: event.id)
            }
            .sheet(isPresented: $showInviteLink) {
                InviteLinkSheet(eventTitle: event.title)
            }
        }
    }

    private func memberRow(_ member: EventMember, isPending: Bool = false) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(avatarColor(for: member.name))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(member.name.prefix(1).uppercased())
                        .font(GatherFont.callout)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .opacity(isPending ? 0.6 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(GatherFont.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(isPending ? Color.gatherSecondaryText : Color.gatherPrimaryText)

                HStack(spacing: 4) {
                    Image(systemName: member.role.icon)
                        .font(.system(size: 10))
                    Text(member.role.rawValue)
                    if isPending {
                        Text("· Pending")
                            .foregroundStyle(Color.rsvpMaybeFallback)
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)
            }

            Spacer()

            if isPending {
                if let code = member.inviteCode {
                    Button {
                        UIPasteboard.general.string = code
                        copiedCode = code
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copiedCode = nil
                        }
                    } label: {
                        Text(copiedCode == code ? "Copied!" : code)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(copiedCode == code ? Color.rsvpYesFallback : Color.accentPurpleFallback)
                            .padding(.horizontal, 8)
                            .padding(.vertical, Spacing.xxs)
                            .background(Color.accentPurpleFallback.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            } else {
                Menu {
                    ForEach([EventRole.admin, .manager, .viewer], id: \.self) { role in
                        Button {
                            member.role = role
                        } label: {
                            HStack {
                                Text(role.rawValue)
                                if member.role == role {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Remove", role: .destructive) {
                        modelContext.delete(member)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.gatherSecondaryText)
                        .padding(Spacing.xs)
                }
            }
        }
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.purple, .blue, .green, .orange, .pink, .teal, .indigo]
        let index = name.stableHash % colors.count
        return colors[index]
    }
}

// MARK: - Add Member Sheet

struct AddMemberSheet: View {
    let eventId: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var selectedRole: EventRole = .manager

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone (optional)", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("Role") {
                    Picker("Role", selection: $selectedRole) {
                        ForEach([EventRole.admin, .manager, .viewer], id: \.self) { role in
                            HStack {
                                Image(systemName: role.icon)
                                Text(role.rawValue)
                            }
                            .tag(role)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Text(selectedRole.description)
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }
            .navigationTitle("Add Team Member")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                sendInviteBar
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Primary CTA

    private var sendInviteBar: some View {
        Button {
            sendInvite()
        } label: {
            Text("Send Invite")
                .font(GatherFont.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(LinearGradient.gatherAccentGradient)
                .clipShape(Capsule())
        }
        .disabled(name.isEmpty)
        .opacity(name.isEmpty ? 0.5 : 1)
        .horizontalPadding()
        .padding(.vertical, Spacing.sm)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .shadow(color: .black.opacity(0.1), radius: 15, y: -6)
        )
    }

    private func sendInvite() {
        let member = EventMember(
            eventId: eventId,
            name: name,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            role: selectedRole
        )
        modelContext.insert(member)

        // Create notification for demo
        let notification = AppNotification(
            type: .memberInvite,
            title: "Invite Sent",
            body: "\(name) has been invited as \(selectedRole.rawValue)"
        )
        modelContext.insert(notification)

        HapticService.success()
        dismiss()
    }
}

// MARK: - Invite Link Sheet

struct InviteLinkSheet: View {
    let eventTitle: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: EventRole = .manager
    @State private var copied = false
    // Generated once (not per render) so the displayed, copied, and shared link
    // all match.
    @State private var inviteLink = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(LinearGradient.gatherAccentGradient)

                VStack(spacing: Spacing.xs) {
                    Text("Share Invite Link")
                        .font(GatherFont.title3)
                    Text("Anyone with this link can join \"\(eventTitle)\" as a \(selectedRole.rawValue.lowercased()).")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .multilineTextAlignment(.center)
                }

                // Role picker
                Picker("Role", selection: $selectedRole) {
                    Text("Admin").tag(EventRole.admin)
                    Text("Manager").tag(EventRole.manager)
                    Text("Viewer").tag(EventRole.viewer)
                }
                .pickerStyle(.segmented)

                // Link display
                HStack {
                    Text(inviteLink)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Color.gatherPrimaryText)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = inviteLink
                        copied = true
                        HapticService.success()
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copied = false
                        }
                    } label: {
                        Text(copied ? "Copied!" : "Copy")
                            .font(GatherFont.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                copied
                                    ? AnyShapeStyle(Color.rsvpYesFallback)
                                    : AnyShapeStyle(LinearGradient.gatherAccentGradient)
                            )
                            .clipShape(Capsule())
                    }
                }
                .padding()
                .background(Color.gatherSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

                // Native share — lets the host send the link through Messages,
                // WhatsApp, Mail, or anything else installed.
                ShareLink(item: inviteLink) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Link")
                    }
                    .font(GatherFont.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
                }

                Spacer()
            }
            .horizontalPadding()
            .padding(.vertical)
            .navigationTitle("Invite Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if inviteLink.isEmpty {
                    inviteLink = "gather.app/join/\(UUID().uuidString.prefix(8).lowercased())"
                }
            }
        }
    }
}

#Preview {
    EventTeamSheet(event: Event(title: "Test Event", startDate: Date()))
        .environmentObject(AuthManager())
        .modelContainer(for: EventMember.self, inMemory: true)
}
