import SwiftUI
import SwiftData
import ContactsUI

struct ContactsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.name) private var allGuests: [Guest]
    @State private var searchText = ""
    @State private var showImportSheet = false

    private var uniqueContacts: [Guest] {
        // Deduplicate guests by email or name to build a contact-like list
        var seen = Set<String>()
        return allGuests.filter { guest in
            let key = guest.email ?? guest.name
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private var filteredContacts: [Guest] {
        if searchText.isEmpty {
            return uniqueContacts
        }
        let query = searchText.lowercased()
        return uniqueContacts.filter { guest in
            guest.name.lowercased().contains(query) ||
            (guest.email?.lowercased().contains(query) ?? false) ||
            (guest.phone?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if uniqueContacts.isEmpty {
                    VStack {
                        Spacer()
                        GatherEmptyState(
                            icon: "person.crop.rectangle.stack",
                            title: "No Contacts Yet",
                            message: "Import contacts from your phone or add guests to events to build your contact list.",
                            actionTitle: "Import Contacts",
                            action: { showImportSheet = true }
                        )
                        Spacer()
                    }
                    .horizontalPadding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: Spacing.sm) {
                            searchField

                            if filteredContacts.isEmpty {
                                GatherEmptyState(
                                    icon: "magnifyingglass",
                                    title: "No Matches",
                                    message: "No contacts match \"\(searchText)\". Try a different name, email, or phone number."
                                )
                                .padding(.top, Spacing.lg)
                            } else {
                                ForEach(filteredContacts) { guest in
                                    ContactRow(
                                        name: guest.name,
                                        email: guest.email,
                                        phone: guest.phone
                                    )
                                    .padding(Spacing.sm)
                                    .surfaceCard(cornerRadius: CornerRadius.md)
                                }
                            }
                        }
                        .padding(.vertical, Spacing.md)
                        .horizontalPadding()
                    }
                }
            }
            .background(Color.gatherBackground)
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showImportSheet = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                ImportContactsSheet(onImport: { contacts in
                    importContacts(contacts)
                })
            }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.callout)
                .foregroundStyle(Color.gatherSecondaryText)

            TextField("Search contacts", text: $searchText)
                .font(GatherFont.body)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.callout)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.gatherSecondaryBackground)
        .clipShape(Capsule())
        .padding(.bottom, Spacing.xs)
    }

    private func importContacts(_ contacts: [CNContact]) {
        for contact in contacts {
            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let email = contact.emailAddresses.first?.value as String?
            let phone = contact.phoneNumbers.first?.value.stringValue

            // Check if already exists
            let exists = allGuests.contains { guest in
                if let existingEmail = guest.email, let newEmail = email {
                    return existingEmail.lowercased() == newEmail.lowercased()
                }
                return guest.name.lowercased() == name.lowercased()
            }

            if !exists && !name.isEmpty {
                let guest = Guest(
                    name: name,
                    email: email,
                    phone: phone
                )
                modelContext.insert(guest)
            }
        }
        modelContext.safeSave()
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let name: String
    let email: String?
    var phone: String? = nil
    var avatarURL: URL? = nil

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Avatar
            Circle()
                .fill(avatarColor)
                .frame(width: AvatarSize.md, height: AvatarSize.md)
                .overlay {
                    Text(name.prefix(1).uppercased())
                        .font(GatherFont.headline)
                        .foregroundStyle(.white)
                }

            // Info
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(name)
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherPrimaryText)

                if let email = email {
                    Text(email)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                if let phone = phone {
                    Text(phone)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var avatarColor: Color {
        let colors: [Color] = [.purple, .blue, .green, .orange, .pink, .teal]
        let index = name.stableHash % colors.count
        return colors[index]
    }
}

// MARK: - Import Contacts Sheet

struct ImportContactsSheet: View {
    @Environment(\.dismiss) var dismiss
    var onImport: ([CNContact]) -> Void
    @State private var showPicker = false
    @State private var selectedContacts: [CNContact] = []
    @State private var contactsAccessDenied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                if contactsAccessDenied {
                    // Permission denied state
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.rsvpNoFallback)

                        Text("Contacts Access Denied")
                            .font(GatherFont.title3)
                            .foregroundStyle(Color.gatherPrimaryText)

                        Text("Gather needs access to your contacts to import them. Please enable Contacts access in Settings.")
                            .font(GatherFont.body)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .multilineTextAlignment(.center)

                        Button {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL)
                            }
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "gear")
                                Text("Open Settings")
                            }
                            .font(GatherFont.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(LinearGradient.gatherAccentGradient)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.top, Spacing.xl)
                } else {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.accentPurpleFallback)

                        Text("Import Contacts")
                            .font(GatherFont.title3)
                            .foregroundStyle(Color.gatherPrimaryText)

                        Text("Select contacts from your phone to add to your Gather contact list.")
                            .font(GatherFont.body)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Spacing.xl)

                    Button {
                        checkContactsAccessAndShowPicker()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "person.2.fill")
                            Text("Choose Contacts")
                                .fontWeight(.bold)
                        }
                        .font(GatherFont.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                    }

                    if !selectedContacts.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("\(selectedContacts.count) contacts selected")
                                .font(GatherFont.callout)
                                .foregroundStyle(Color.gatherSecondaryText)

                            ScrollView {
                                LazyVStack(spacing: Spacing.xs) {
                                    ForEach(selectedContacts, id: \.identifier) { contact in
                                        let name = [contact.givenName, contact.familyName]
                                            .filter { !$0.isEmpty }
                                            .joined(separator: " ")
                                        HStack {
                                            Text(name)
                                                .font(GatherFont.body)
                                            Spacer()
                                            if let email = contact.emailAddresses.first?.value as String? {
                                                Text(email)
                                                    .font(GatherFont.caption)
                                                    .foregroundStyle(Color.gatherSecondaryText)
                                            }
                                        }
                                        .padding(Spacing.sm)
                                        .surfaceCard(cornerRadius: CornerRadius.sm)
                                    }
                                }
                            }
                        }
                    }
                } // end else (contacts access not denied)

                Spacer()
            }
            .horizontalPadding()
            .background(Color.gatherBackground)
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport(selectedContacts)
                        dismiss()
                    }
                    .disabled(selectedContacts.isEmpty)
                }
            }
            .sheet(isPresented: $showPicker) {
                ContactsPickerView(selectedContacts: $selectedContacts)
            }
        }
    }

    private func checkContactsAccessAndShowPicker() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .denied, .restricted:
            contactsAccessDenied = true
        default:
            showPicker = true
        }
    }
}

// MARK: - Preview
// Note: ContactsPickerView is defined in AddGuestSheet.swift and reused here

#Preview {
    ContactsView()
        .modelContainer(for: Guest.self, inMemory: true)
}
