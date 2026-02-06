import SwiftUI

struct ContactsView: View {
    @State private var searchText = ""
    @State private var showImportSheet = false

    var body: some View {
        NavigationStack {
            List {
                // Groups Section
                Section("Groups") {
                    NavigationLink {
                        Text("All Contacts")
                    } label: {
                        Label("All Contacts", systemImage: "person.2")
                    }

                    NavigationLink {
                        Text("Favorites")
                    } label: {
                        Label("Favorites", systemImage: "star")
                    }

                    NavigationLink {
                        Text("Recent")
                    } label: {
                        Label("Recent Invites", systemImage: "clock")
                    }
                }

                // Recent Contacts Section
                Section("Recent") {
                    // Placeholder for recent contacts
                    ForEach(0..<3) { index in
                        ContactRow(
                            name: "Contact \(index + 1)",
                            email: "contact\(index + 1)@example.com"
                        )
                    }
                }
            }
            .navigationTitle("Contacts")
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showImportSheet = true
                        } label: {
                            Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus")
                        }

                        Button {
                            // Import from CSV
                        } label: {
                            Label("Import CSV", systemImage: "doc.text")
                        }

                        Button {
                            // Add manually
                        } label: {
                            Label("Add Manually", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                ImportContactsSheet()
            }
        }
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
                .fill(Color.gatherSecondaryBackground)
                .frame(width: AvatarSize.md, height: AvatarSize.md)
                .overlay {
                    Text(name.prefix(1).uppercased())
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherSecondaryText)
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
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Import Contacts Sheet

struct ImportContactsSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedContacts: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack {
                Text("Import from Contacts")
                    .font(GatherFont.title2)
                    .padding()

                Text("Coming soon...")
                    .foregroundStyle(Color.gatherSecondaryText)

                Spacer()
            }
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
                        dismiss()
                    }
                    .disabled(selectedContacts.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContactsView()
}
