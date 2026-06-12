import SwiftUI

struct GuestActionBar: View {
    let event: Event
    let selectedGuests: Set<UUID>
    @Binding var isSelectionMode: Bool
    @Binding var showAddGuest: Bool
    @Binding var showSendInvites: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Selection mode toggle / Cancel
            if isSelectionMode {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isSelectionMode = false
                    }
                } label: {
                    Text("Cancel")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                // Selected count
                Text("\(selectedGuests.count) selected")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherPrimaryText)

                Spacer()

                // Send to Selected
                Button {
                    showSendInvites = true
                } label: {
                    Label("Send Invites", systemImage: "paperplane.fill")
                        .font(GatherFont.callout)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            selectedGuests.isEmpty
                                ? AnyShapeStyle(Color.gatherSecondaryText.opacity(0.4))
                                : AnyShapeStyle(LinearGradient.gatherAccentGradient)
                        )
                        .clipShape(Capsule())
                }
                .disabled(selectedGuests.isEmpty)
            } else {
                // Add Guest
                Button {
                    showAddGuest = true
                } label: {
                    Label("Add Guest", systemImage: "person.badge.plus")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.accentPurpleFallback)
                }

                Spacer()

                // Select & Send
                if !event.guests.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            isSelectionMode = true
                        }
                    } label: {
                        Label("Select", systemImage: "checkmark.circle")
                            .font(GatherFont.callout)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }

                    // Send All
                    Button {
                        showSendInvites = true
                    } label: {
                        Label("Send All", systemImage: "paperplane.fill")
                            .font(GatherFont.callout)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(LinearGradient.gatherAccentGradient)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        // Floating bar over scrolling content — glass stays per design whitelist.
        .background(.ultraThinMaterial)
        .shadow(color: .black.opacity(0.1), radius: 15, y: -6)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isSelectionMode = false
    @Previewable @State var showAddGuest = false
    @Previewable @State var showSendInvites = false

    let event = Event(title: "Wedding", startDate: Date())

    VStack {
        Spacer()
        GuestActionBar(
            event: event,
            selectedGuests: [],
            isSelectionMode: $isSelectionMode,
            showAddGuest: $showAddGuest,
            showSendInvites: $showSendInvites
        )
    }
}
