import SwiftUI
import Contacts
import ContactsUI

struct AddGuestSheet: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var event: Event

    @State private var selectedTab = 0
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var role: GuestRole = .guest
    @State private var showContactsPicker = false
    @State private var selectedContacts: [CNContact] = []
    @State private var isImporting = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Modern tab toggle
                HStack(spacing: Spacing.xs) {
                    AddGuestTabButton(
                        label: "Manual",
                        icon: "pencil.line",
                        isSelected: selectedTab == 0
                    ) { withAnimation(.spring(response: 0.3)) { selectedTab = 0 } }

                    AddGuestTabButton(
                        label: "Contacts",
                        icon: "person.crop.rectangle.stack",
                        isSelected: selectedTab == 1
                    ) { withAnimation(.spring(response: 0.3)) { selectedTab = 1 } }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)

                TabView(selection: $selectedTab) {
                    manualEntryView.tag(0)
                    contactsImportView.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Add Guests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }
            }
            .sheet(isPresented: $showContactsPicker) {
                ContactsPickerView(selectedContacts: $selectedContacts)
            }
        }
    }

    // MARK: - Manual Entry View

    private var manualEntryView: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Success banner
                if showSuccess {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.rsvpYesFallback)
                        Text("Guest added!")
                            .font(GatherFont.callout)
                            .fontWeight(.semibold)
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(Color.rsvpYesFallback.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Guest info card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentPurpleFallback)
                        Text("Guest Information")
                            .font(GatherFont.headline)
                    }

                    // Name (required)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("NAME")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.gatherSecondaryText)
                                .tracking(0.5)
                            Text("*")
                                .font(.caption2)
                                .foregroundStyle(Color.accentPinkFallback)
                        }
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "person")
                                .font(.caption)
                                .foregroundStyle(Color.accentPurpleFallback.opacity(0.7))
                                .frame(width: 20)
                            TextField("Guest name", text: $name)
                                .font(GatherFont.body)
                                .textContentType(.name)
                        }
                        .padding(Spacing.sm)
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }

                    // Email
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EMAIL")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .tracking(0.5)
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "envelope")
                                .font(.caption)
                                .foregroundStyle(Color.accentPurpleFallback.opacity(0.7))
                                .frame(width: 20)
                            TextField("email@example.com", text: $email)
                                .font(GatherFont.body)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                        }
                        .padding(Spacing.sm)
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }

                    // Phone
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PHONE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .tracking(0.5)
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "phone")
                                .font(.caption)
                                .foregroundStyle(Color.accentPurpleFallback.opacity(0.7))
                                .frame(width: 20)
                            TextField("(555) 555-5555", text: $phone)
                                .font(GatherFont.body)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                        }
                        .padding(Spacing.sm)
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }

                    // Role pills
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ROLE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .tracking(0.5)

                        HStack(spacing: Spacing.xs) {
                            ForEach(GuestRole.allCases, id: \.self) { guestRole in
                                Button {
                                    withAnimation(.spring(response: 0.25)) { role = guestRole }
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: guestRole.icon)
                                            .font(.system(size: 10))
                                        Text(guestRole.displayName)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    .foregroundStyle(role == guestRole ? .white : Color.gatherPrimaryText)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xs)
                                    .background(
                                        role == guestRole
                                            ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                                            : AnyShapeStyle(Color.gatherSecondaryBackground)
                                    )
                                    .clipShape(Capsule())
                                }
                                .scaleEffect(role == guestRole ? 1.03 : 1.0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: role == guestRole)
                            }
                        }
                    }
                }
                .padding(Spacing.md)
                .background(Color.gatherSecondaryBackground.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))

                // Add button
                Button {
                    addGuest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.callout)
                        Text("Add Guest")
                            .font(GatherFont.callout)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        name.isEmpty
                            ? AnyShapeStyle(Color.gatherSecondaryText.opacity(0.3))
                            : AnyShapeStyle(LinearGradient.gatherAccentGradient)
                    )
                    .clipShape(Capsule())
                }
                .disabled(name.isEmpty)
                .scaleEffect(name.isEmpty ? 0.97 : 1.0)
                .animation(.spring(response: 0.3), value: name.isEmpty)
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Contacts Import View

    private var contactsImportView: some View {
        VStack(spacing: Spacing.lg) {
            if selectedContacts.isEmpty {
                VStack(spacing: Spacing.md) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.accentPurpleFallback.opacity(0.08))
                            .frame(width: 110, height: 110)
                        Circle()
                            .fill(Color.accentPinkFallback.opacity(0.06))
                            .frame(width: 80, height: 80)
                        Image(systemName: "person.crop.rectangle.stack.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(LinearGradient.gatherAccentGradient)
                    }

                    Text("Import from Contacts")
                        .font(GatherFont.title3)
                        .fontWeight(.semibold)

                    Text("Quickly add guests from your phone contacts")
                        .font(GatherFont.body)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)

                    Button {
                        showContactsPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .font(.callout)
                            Text("Choose Contacts")
                                .font(GatherFont.callout)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.sm)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Selected contacts
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.rsvpYesFallback)
                            Text("\(selectedContacts.count) contacts selected")
                                .font(GatherFont.headline)
                        }

                        Spacer()

                        Button {
                            showContactsPicker = true
                        } label: {
                            Text("Change")
                                .font(GatherFont.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentPurpleFallback)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, 4)
                                .background(Color.accentPurpleFallback.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, Spacing.md)

                    ScrollView {
                        LazyVStack(spacing: Spacing.xs) {
                            ForEach(selectedContacts, id: \.identifier) { contact in
                                HStack(spacing: Spacing.sm) {
                                    Circle()
                                        .fill(LinearGradient.gatherAccentGradient)
                                        .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                                        .overlay {
                                            Text(String(contact.givenName.prefix(1)))
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                        }

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("\(contact.givenName) \(contact.familyName)")
                                            .font(GatherFont.callout)
                                            .fontWeight(.medium)
                                            .lineLimit(1)

                                        if let emailVal = contact.emailAddresses.first?.value as String? {
                                            Text(emailVal)
                                                .font(.caption2)
                                                .foregroundStyle(Color.gatherSecondaryText)
                                                .lineLimit(1)
                                        } else if let phoneVal = contact.phoneNumbers.first?.value.stringValue {
                                            Text(phoneVal)
                                                .font(.caption2)
                                                .foregroundStyle(Color.gatherSecondaryText)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(Spacing.sm)
                                .background(Color.gatherSecondaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                    }

                    // Import button
                    Button {
                        importSelectedContacts()
                    } label: {
                        HStack(spacing: 6) {
                            if isImporting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.callout)
                            }
                            Text(isImporting ? "Importing..." : "Import \(selectedContacts.count) Guests")
                                .font(GatherFont.callout)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                    }
                    .disabled(isImporting)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
                }
            }
        }
    }

    // MARK: - Actions

    private func addGuest() {
        let guest = Guest(
            name: name.trimmingCharacters(in: .whitespaces),
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            role: role
        )

        event.guests.append(guest)

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Show success briefly
        withAnimation(.spring(response: 0.3)) { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSuccess = false }
        }

        // Reset form
        name = ""
        email = ""
        phone = ""
        role = .guest
    }

    private func importSelectedContacts() {
        isImporting = true

        for contact in selectedContacts {
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let emailValue = contact.emailAddresses.first?.value as String?
            let phoneValue = contact.phoneNumbers.first?.value.stringValue

            let guest = Guest(
                name: fullName.isEmpty ? "Guest" : fullName,
                email: emailValue,
                phone: phoneValue
            )

            event.guests.append(guest)
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        isImporting = false
        dismiss()
    }
}

// MARK: - Add Guest Tab Button

private struct AddGuestTabButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(label)
                    .font(GatherFont.callout)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                    : AnyShapeStyle(Color.gatherSecondaryBackground)
            )
            .clipShape(Capsule())
        }
    }
}

// MARK: - Contacts Picker

struct ContactsPickerView: UIViewControllerRepresentable {
    @Binding var selectedContacts: [CNContact]
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactsPickerView

        init(_ parent: ContactsPickerView) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.selectedContacts = contacts
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.dismiss()
        }
    }
}

#Preview {
    AddGuestSheet(event: Event(title: "Sample Event"))
}
