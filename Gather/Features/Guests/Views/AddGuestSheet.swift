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
    @State private var successMessage = "Guest added!"
    @State private var importSummary: String?
    @State private var pasteText = ""
    @FocusState private var nameFieldFocused: Bool

    private var isEmailValid: Bool {
        email.isEmpty || (email.contains("@") && email.split(separator: "@").last?.contains(".") == true)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && isEmailValid
    }

    /// Single source of truth for duplicate-confirm UI: the warning card and
    /// the CTA's "Add Anyway" label/icon/accessibility must flip together.
    private var showDuplicateConfirm: Bool {
        possibleDuplicate != nil && canSave
    }

    // MARK: - Duplicate Detection

    private func digitsOnly(_ value: String) -> String {
        value.filter { $0.isNumber }
    }

    /// Existing event guest that likely matches the manual-entry fields:
    /// case-insensitive email, digits-only phone, or case-insensitive exact name.
    private var possibleDuplicate: Guest? {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let phoneDigits = digitsOnly(phone)

        guard !trimmedName.isEmpty || !trimmedEmail.isEmpty || !phoneDigits.isEmpty else {
            return nil
        }

        return event.guests.first { guest in
            if !trimmedEmail.isEmpty,
               let guestEmail = guest.email,
               guestEmail.caseInsensitiveCompare(trimmedEmail) == .orderedSame {
                return true
            }
            if !phoneDigits.isEmpty,
               let guestPhone = guest.phone,
               digitsOnly(guestPhone) == phoneDigits {
                return true
            }
            if !trimmedName.isEmpty,
               guest.name.caseInsensitiveCompare(trimmedName) == .orderedSame {
                return true
            }
            return false
        }
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

                    AddGuestTabButton(
                        label: "Paste List",
                        icon: "list.clipboard",
                        isSelected: selectedTab == 2
                    ) { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { selectedTab = 2 } }
                }
                .horizontalPadding()
                .padding(.vertical, Spacing.sm)

                TabView(selection: $selectedTab) {
                    manualEntryView.tag(0)
                    contactsImportView.tag(1)
                    pasteListView.tag(2)
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

                // Batch entry: the sheet stays open after each add, so an
                // explicit Done is the "I'm finished" affordance.
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(GatherFont.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentPurpleFallback)
                    }
                    .accessibilityLabel("Done adding guests")
                }
            }
            .sheet(isPresented: $showContactsPicker) {
                ContactsPickerView(selectedContacts: $selectedContacts)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .alert(
                "Import Complete",
                isPresented: Binding(
                    get: { importSummary != nil },
                    set: { if !$0 { importSummary = nil; dismiss() } }
                )
            ) {
                Button("OK") { }
            } message: {
                Text(importSummary ?? "")
            }
            .onAppear {
                // Focus Name on first open (Manual tab only) so the host can
                // start typing immediately — the sheet is built for batch entry
                // but only refocused after the first add. The short delay lets
                // the sheet settle, matching the post-add refocus.
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    if selectedTab == 0 { nameFieldFocused = true }
                }
            }
        }
    }

    // MARK: - Capacity Banner

    @ViewBuilder
    private var capacityBanner: some View {
        if event.isFull {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.caption)
                    .foregroundStyle(Color.rsvpMaybeFallback)
                Text("Event is at capacity — new guests join the waitlist")
                    .font(GatherFont.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.gatherPrimaryText)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.rsvpMaybeFallback.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Event is at capacity. New guests join the waitlist.")
        }
    }

    // MARK: - Manual Entry View

    private var manualEntryView: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {

                // Capacity banner
                capacityBanner

                // Success banner
                if showSuccess {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.rsvpYesFallback)
                        Text(successMessage)
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
                                .focused($nameFieldFocused)
                                // Rapid batch entry: type name → return → next name.
                                .onSubmit { if canSave { addGuest() } }
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
                                .onSubmit { if canSave { addGuest() } }
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
                                // No return key on .phonePad, but hardware
                                // keyboards can still submit.
                                .onSubmit { if canSave { addGuest() } }
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
                                            // Scales with Dynamic Type, unlike a fixed 10pt.
                                            .font(.caption2)
                                            .imageScale(.small)
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

                // Duplicate warning
                if showDuplicateConfirm, let duplicate = possibleDuplicate {
                    HStack(alignment: .top, spacing: Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.rsvpMaybeFallback)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(duplicate.name) may already be on the list")
                                .font(GatherFont.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.gatherPrimaryText)
                            Text("Tap Add Anyway if this is a different person.")
                                .font(GatherFont.caption)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.rsvpMaybeFallback.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Warning: \(duplicate.name) may already be on the list. Tap Add Anyway if this is a different person.")
                }

                // Add button — becomes an explicit "Add Anyway" confirm
                // when a possible duplicate is detected.
                Button {
                    addGuest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showDuplicateConfirm ? "exclamationmark.triangle.fill" : "plus.circle.fill")
                            .font(.callout)
                        Text(showDuplicateConfirm ? "Add Anyway" : "Add Guest")
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
                .accessibilityLabel(showDuplicateConfirm ? "Add anyway, possible duplicate" : "Add guest")
            }
            .padding(.vertical, Spacing.md)
            .horizontalPadding()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Contacts Import View

    private var contactsImportView: some View {
        VStack(spacing: Spacing.lg) {
            capacityBanner
                .horizontalPadding()
                .padding(.top, Spacing.xs)

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

    // MARK: - Paste List Import

    /// One parsed line from the paste box: "Name" or "Name, phone-or-email".
    private struct PastedEntry {
        let name: String
        let email: String?
        let phone: String?
    }

    /// Lines -> entries. Blank lines are skipped; an optional part after the
    /// first comma becomes an email (contains "@") or a phone (7+ digits).
    private func parsePastedEntries(_ text: String) -> [PastedEntry] {
        text.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }

            var entryName = line
            var entryEmail: String?
            var entryPhone: String?

            if let commaIndex = line.firstIndex(of: ",") {
                entryName = String(line[..<commaIndex]).trimmingCharacters(in: .whitespaces)
                let contact = String(line[line.index(after: commaIndex)...])
                    .trimmingCharacters(in: .whitespaces)
                if contact.contains("@") {
                    entryEmail = contact
                } else if contact.filter({ $0.isNumber }).count >= 7 {
                    entryPhone = contact
                }
            }

            guard !entryName.isEmpty else { return nil }
            return PastedEntry(name: entryName, email: entryEmail, phone: entryPhone)
        }
    }

    /// Parsed entries split into new guests vs. duplicates, using the same
    /// keys as the contacts import (email lowercased, phone digits-only,
    /// name lowercased) — checked against existing guests AND within the
    /// pasted batch itself.
    private var pasteParseResult: (toAdd: [PastedEntry], skipped: Int) {
        var existingEmails = Set(
            event.guests.compactMap { $0.email?.trimmingCharacters(in: .whitespaces).lowercased() }
        )
        var existingPhones = Set(
            event.guests.compactMap { $0.phone.map(digitsOnly) }.filter { !$0.isEmpty }
        )
        var existingNames = Set(event.guests.map { $0.name.lowercased() })

        var toAdd: [PastedEntry] = []
        var skipped = 0

        for entry in parsePastedEntries(pasteText) {
            let emailKey = entry.email?.lowercased()
            let phoneKey = entry.phone.map(digitsOnly)
            let nameKey = entry.name.lowercased()

            let isDuplicate =
                (emailKey.map { existingEmails.contains($0) } ?? false) ||
                (phoneKey.map { !$0.isEmpty && existingPhones.contains($0) } ?? false) ||
                existingNames.contains(nameKey)

            if isDuplicate {
                skipped += 1
                continue
            }

            toAdd.append(entry)
            if let emailKey { existingEmails.insert(emailKey) }
            if let phoneKey, !phoneKey.isEmpty { existingPhones.insert(phoneKey) }
            existingNames.insert(nameKey)
        }

        return (toAdd, skipped)
    }

    private var pasteListView: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                capacityBanner

                // Paste box card
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.clipboard")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentPurpleFallback)
                        Text("Paste Your List")
                            .font(GatherFont.headline)

                        Spacer()

                        Button {
                            if let clip = UIPasteboard.general.string,
                               !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                pasteText = pasteText.isEmpty ? clip : pasteText + "\n" + clip
                                HapticService.buttonTap()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.caption2)
                                Text("Paste")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(Color.accentPurpleFallback)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xxs)
                            .background(Color.accentPurpleFallback.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .accessibilityLabel("Paste from clipboard")
                    }

                    Text("One guest per line. Add a phone or email after a comma — e.g. \"Priya Sharma, 555-201-8890\".")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    TextEditor(text: $pasteText)
                        .font(GatherFont.body)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 170)
                        .padding(Spacing.xs)
                        .background(Color.gatherTertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        .overlay(alignment: .topLeading) {
                            if pasteText.isEmpty {
                                Text("Priya Sharma, 555-201-8890\nArjun Patel, arjun@example.com\nMeera Nair")
                                    .font(GatherFont.body)
                                    .foregroundStyle(Color.gatherSecondaryText.opacity(0.5))
                                    .padding(.horizontal, Spacing.xs + 5)
                                    .padding(.vertical, Spacing.xs + 8)
                                    .allowsHitTesting(false)
                            }
                        }
                        .accessibilityLabel("Guest list, one guest per line")
                }
                .padding(Spacing.md)
                .surfaceCard()

                pastePreviewCard

                pasteConfirmButton
            }
            .padding(.vertical, Spacing.md)
            .horizontalPadding()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// Live "Will add N guests" preview so the host can sanity-check the
    /// parse before committing.
    @ViewBuilder
    private var pastePreviewCard: some View {
        let result = pasteParseResult
        if !pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if result.toAdd.isEmpty && result.skipped > 0 {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.rsvpMaybeFallback)
                    Text("All \(result.skipped) pasted guest\(result.skipped == 1 ? " is" : "s are") already on the list")
                        .font(GatherFont.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.gatherPrimaryText)
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.rsvpMaybeFallback.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .accessibilityElement(children: .combine)
            } else if !result.toAdd.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.rsvpYesFallback)
                        Text("Will add \(result.toAdd.count) guest\(result.toAdd.count == 1 ? "" : "s")")
                            .font(GatherFont.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.gatherPrimaryText)
                        if result.skipped > 0 {
                            Text("· \(result.skipped) already added — skipped")
                                .font(GatherFont.caption)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                    }

                    Text(pastePreviewNames(result.toAdd))
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .lineLimit(2)
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.rsvpYesFallback.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func pastePreviewNames(_ entries: [PastedEntry]) -> String {
        let shown = entries.prefix(6).map { $0.name }
        let overflow = entries.count - shown.count
        return overflow > 0
            ? shown.joined(separator: ", ") + " +\(overflow) more"
            : shown.joined(separator: ", ")
    }

    private var pasteConfirmButton: some View {
        let count = pasteParseResult.toAdd.count
        return Button {
            addPastedGuests()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.2.badge.plus.fill")
                    .font(.callout)
                Text(count > 0 ? "Add \(count) Guest\(count == 1 ? "" : "s")" : "Add Guests")
                    .font(GatherFont.callout)
                    .fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                count > 0
                    ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                    : AnyShapeStyle(Color.gatherSecondaryText.opacity(0.3))
            )
            .clipShape(Capsule())
        }
        .disabled(count == 0)
        .scaleEffect(count > 0 ? 1.0 : 0.97)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: count > 0)
        .accessibilityLabel(count > 0 ? "Add \(count) guests from pasted list" : "Add guests from pasted list")
    }

    private func addPastedGuests() {
        let result = pasteParseResult
        guard !result.toAdd.isEmpty else { return }

        for entry in result.toAdd {
            let guest = Guest(
                name: entry.name,
                email: entry.email,
                phone: entry.phone,
                // Evaluated per append so a batch that crosses capacity
                // waitlists only the overflow.
                status: event.isFull ? .waitlisted : .pending
            )
            event.guests.append(guest)
        }
        modelContext.safeSave()

        HapticService.success()

        let added = result.toAdd.count
        pasteText = ""
        // Same summary alert as the contacts import; sheet dismisses on OK.
        importSummary = result.skipped > 0
            ? "Added \(added) guest\(added == 1 ? "" : "s"). Skipped \(result.skipped) already on the list."
            : "Added \(added) guest\(added == 1 ? "" : "s")."
    }

    // MARK: - Actions

    private func addGuest() {
        // At capacity, new guests join the waitlist instead of pending.
        let joinedWaitlist = event.isFull

        // Trim before storing so duplicate detection keys stay reliable.
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)

        let guest = Guest(
            name: trimmedName,
            email: trimmedEmail.isEmpty ? nil : trimmedEmail,
            phone: trimmedPhone.isEmpty ? nil : trimmedPhone,
            status: joinedWaitlist ? .waitlisted : .pending,
            role: role
        )

        event.guests.append(guest)
        modelContext.safeSave()

        HapticService.success()

        // Batch-entry affirmation: name the guest, invite the next one.
        successMessage = joinedWaitlist
            ? "Added \(trimmedName) to waitlist ✓ — add another"
            : "Added \(trimmedName) ✓ — add another"
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showSuccess = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showSuccess = false }
        }

        // Reset form and put the cursor back on Name so the host can keep
        // typing guest after guest without touching the screen.
        name = ""
        email = ""
        phone = ""
        role = .guest
        nameFieldFocused = true
    }

    private func importSelectedContacts() {
        isImporting = true
        // Yield one render pass so the "Importing..." spinner actually shows
        // before the synchronous import work; the loop still runs on the
        // main actor (SwiftData context isn't Sendable).
        Task {
            await Task.yield()
            performContactImport()
        }
    }

    private func performContactImport() {
        // Existing-guest keys for duplicate skipping (also catches dupes
        // within the selected batch as new guests are added).
        var existingEmails = Set(
            event.guests.compactMap { $0.email?.trimmingCharacters(in: .whitespaces).lowercased() }
        )
        var existingPhones = Set(
            event.guests.compactMap { $0.phone.map(digitsOnly) }.filter { !$0.isEmpty }
        )
        var existingNames = Set(event.guests.map { $0.name.lowercased() })

        var importedCount = 0
        var skippedCount = 0

        for contact in selectedContacts {
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let emailValue = contact.emailAddresses.first?.value as String?
            let phoneValue = contact.phoneNumbers.first?.value.stringValue

            let emailKey = emailValue?.trimmingCharacters(in: .whitespaces).lowercased()
            let phoneKey = phoneValue.map(digitsOnly)

            let isDuplicate =
                (emailKey.map { existingEmails.contains($0) } ?? false) ||
                (phoneKey.map { !$0.isEmpty && existingPhones.contains($0) } ?? false) ||
                (!fullName.isEmpty && existingNames.contains(fullName.lowercased()))

            if isDuplicate {
                skippedCount += 1
                continue
            }

            let guest = Guest(
                name: fullName.isEmpty ? "Guest" : fullName,
                email: emailValue,
                phone: phoneValue,
                status: event.isFull ? .waitlisted : .pending
            )

            event.guests.append(guest)
            importedCount += 1

            if let emailKey { existingEmails.insert(emailKey) }
            if let phoneKey, !phoneKey.isEmpty { existingPhones.insert(phoneKey) }
            if !fullName.isEmpty { existingNames.insert(fullName.lowercased()) }
        }
        modelContext.safeSave()

        isImporting = false

        // Always confirm the outcome via the Import Complete alert — the
        // sheet dismisses when it's acknowledged.
        if importedCount == 0 {
            // Nothing was added — warn instead of celebrating.
            HapticService.warning()
            importSummary = "No new guests — all \(skippedCount) were already on the list."
        } else if skippedCount > 0 {
            HapticService.success()
            importSummary = "Imported \(importedCount) guest\(importedCount == 1 ? "" : "s"). Skipped \(skippedCount) already added."
        } else {
            HapticService.success()
            importSummary = "Imported \(importedCount) guest\(importedCount == 1 ? "" : "s")."
        }
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
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
