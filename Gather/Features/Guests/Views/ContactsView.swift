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
                    VStack(spacing: Spacing.lg) {
                        Spacer()

                        Image(systemName: "person.crop.rectangle.stack")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.gatherSecondaryText.opacity(0.5))

                        VStack(spacing: Spacing.sm) {
                            Text("No Contacts Yet")
                                .font(GatherFont.title3)
                                .foregroundStyle(Color.gatherPrimaryText)

                            Text("Import contacts from your phone or add guests to events to build your contact list.")
                                .font(GatherFont.body)
                                .foregroundStyle(Color.gatherSecondaryText)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            showImportSheet = true
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("Import Contacts")
                            }
                            .font(GatherFont.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(LinearGradient.gatherAccentGradient)
                            .clipShape(Capsule())
                        }

                        Spacer()
                    }
                    .horizontalPadding()
                } else {
                    List {
                        ForEach(filteredContacts) { guest in
                            ContactRow(
                                name: guest.name,
                                email: guest.email,
                                phone: guest.phone
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Contacts")
            .searchable(text: $searchText, prompt: "Search contacts")
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
        try? modelContext.save()
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
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Import Contacts Sheet

struct ImportContactsSheet: View {
    @Environment(\.dismiss) var dismiss
    var onImport: ([CNContact]) -> Void
    @State private var showPicker = false
    @State private var selectedContacts: [CNContact] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
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
                    showPicker = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "person.2.fill")
                        Text("Choose Contacts")
                    }
                    .font(GatherFont.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(LinearGradient.gatherAccentGradient)
                    .foregroundStyle(.white)
                    .cornerRadius(CornerRadius.md)
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
                                    .background(Color.gatherSecondaryBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .horizontalPadding()
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
}

// MARK: - Preview
// Note: ContactsPickerView is defined in AddGuestSheet.swift and reused here

#Preview {
    ContactsView()
        .modelContainer(for: Guest.self, inMemory: true)
}
