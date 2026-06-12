import SwiftUI
import Contacts
import ContactsUI

struct AddGuestSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
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

    private var isEmailValid: Bool {
        email.isEmpty || (email.contains("@") && email.split(separator: "@").last?.contains(".") == true)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && isEmailValid
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Modern tab toggle
                HStack(spacing: Spacing.xs) {
                    AddGuestTabButton(
                        label: "Manual",
                        icon: "pencil.line",
                        isSelected: selectedTab == 0
                    ) { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { selectedTab = 0 } }

                    AddGuestTabButton(
                        label: "Contacts",
                        icon: "person.crop.rectangle.stack",
                        isSelected: selectedTab == 1
                    ) { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { selectedTab = 1 } }
                }
                .horizontalPadding()
                .padding(.vertical, Spacing.sm)

                TabView(selection: $selectedTab) {
                    manualEntryView.tag(0)
                    contactsImportView.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color.gatherBackground)
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
                    .accessibilityLabel("Close")
                }
            }
            .sheet(isPresented: $showContactsPicker) {
                ContactsPickerView(selectedContacts: $selectedContacts)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
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
                                .submitLabel(.done)
                        }
                        .padding(Spacing.sm)
                        .background(Color.gatherTertiaryBackground)
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
                                .submitLabel(.done)
                        }
                        .padding(Spacing.sm)
                        .background(Color.gatherTertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(!isEmailValid ? Color.warmCoral : Color.clear, lineWidth: 1)
                        )

                        if !isEmailValid {
                            Text("Enter a valid email address")
                                .font(.caption2)
                                .foregroundStyle(Color.warmCoral)
                                .transition(.opacity)
                        }
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
                                .submitLabel(.done)
                        }
                        .padding(Spacing.sm)
                        .background(Color.gatherTertiaryBackground)
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
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { role = guestRole }
                                    HapticService.buttonTap()
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
                                            : AnyShapeStyle(Color.gatherTertiaryBackground)
                                    )
                                    .clipShape(Capsule())
                                }
                                .scaleEffect(role == guestRole ? 1.03 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: role == guestRole)
                            }
                        }
                    }
                }
                .padding(Spacing.md)
                .surfaceCard()

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
                    .frame(height: 52)
                    .background(
                        canSave
                            ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                            : AnyShapeStyle(Color.gatherSecondaryText.opacity(0.3))
                    )
                    .clipShape(Capsule())
                }
                .disabled(!canSave)
                .scaleEffect(canSave ? 1.0 : 0.97)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canSave)
            }
            .padding(.vertical, Spacing.md)
            .horizontalPadding()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Contacts Import View

    private var contactsImportView: some View {
        VStack(spacing: Spacing.lg) {
            if selectedContacts.isEmpty {
                VStack {
                    Spacer()
                    GatherEmptyState(
                        icon: "person.crop.rectangle.stack",
                        title: "Import from Contacts",
                        message: "Quickly add guests from your phone contacts.",
                        actionTitle: "Choose Contacts",
                        action: { showContactsPicker = true }
                    )
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
                                .padding(.vertical, Spacing.xxs)
                                .background(Color.accentPurpleFallback.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .horizontalPadding()

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
                                .surfaceCard(cornerRadius: CornerRadius.md)
                            }
                        }
                        .horizontalPadding()
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
                        .frame(height: 52)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                    }
                    .disabled(isImporting)
                    .horizontalPadding()
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
        modelContext.safeSave()

        HapticService.success()

        // Show success briefly
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showSuccess = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
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
        modelContext.safeSave()

        HapticService.success()

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
