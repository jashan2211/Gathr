import SwiftUI
import CoreImage.CIFilterBuiltins
import EventKit

struct TicketConfirmationView: View {
    let ticket: Ticket
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var showingCalendarAlert = false
    @State private var calendarMessage = ""
    @State private var showConfetti = false
    @State private var cardAppeared = false

    var body: some View {
        ZStack {
            Color.gatherBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    successHeader
                    ticketCard
                        .scaleEffect(cardAppeared ? 1 : 0.8)
                        .opacity(cardAppeared ? 1 : 0)
                    actionButtons
                    eventSummary
                    doneButton
                }
                .padding()
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
        .alert("Calendar", isPresented: $showingCalendarAlert) {
            Button("OK") {}
        } message: {
            Text(calendarMessage)
        }
        .sheet(isPresented: $showingShareSheet) {
            TicketShareSheet(items: [ticketShareText])
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                cardAppeared = true
            }
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                showConfetti = true
            }
        }
    }

    // MARK: - Success Header

    private var successHeader: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.mintGreen.opacity(0.15))
                    .frame(width: 100, height: 100)

                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.mintGreen, .neonBlue, .mintGreen],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.mintGreen)
            }
            .bouncyAppear()

            Text("You're Going!")
                .font(GatherFont.title)
                .foregroundStyle(Color.gatherPrimaryText)

            Text("Confirmation #\(ticket.ticketNumber)")
                .font(GatherFont.callout)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .padding(.top, Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Confirmed. You're going! Confirmation number \(ticket.ticketNumber)")
    }

    // MARK: - Ticket Card (Apple Wallet Style)

    private var ticketCard: some View {
        VStack(spacing: 0) {
            // Top section
            VStack(spacing: Spacing.md) {
                Text(event.category.emoji)
                    .font(.system(size: 36))

                Text(event.title)
                    .font(GatherFont.headline)
                    .multilineTextAlignment(.center)

                HStack(spacing: Spacing.lg) {
                    VStack(spacing: 2) {
                        Text("DATE")
                            .font(.caption2)
                            .foregroundStyle(Color.gatherSecondaryText)
                        Text(formattedDate)
                            .font(GatherFont.callout)
                            .fontWeight(.semibold)
                    }

                    Rectangle()
                        .fill(Color.gatherSeparator)
                        .frame(width: 1, height: 30)

                    VStack(spacing: 2) {
                        Text("TIME")
                            .font(.caption2)
                            .foregroundStyle(Color.gatherSecondaryText)
                        Text(formattedTime)
                            .font(GatherFont.callout)
                            .fontWeight(.semibold)
                    }

                    Rectangle()
                        .fill(Color.gatherSeparator)
                        .frame(width: 1, height: 30)

                    VStack(spacing: 2) {
                        Text("QTY")
                            .font(.caption2)
                            .foregroundStyle(Color.gatherSecondaryText)
                        Text("\(ticket.quantity)")
                            .font(GatherFont.callout)
                            .fontWeight(.semibold)
                    }
                }

                Text(ticket.guestName)
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity)

            // Perforated line
            HStack(spacing: 0) {
                Circle()
                    .fill(Color.gatherBackground)
                    .frame(width: 24, height: 24)
                    .offset(x: -12)

                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(Color.gatherSeparator)
                    .frame(height: 1)

                Circle()
                    .fill(Color.gatherBackground)
                    .frame(width: 24, height: 24)
                    .offset(x: 12)
            }

            // QR Code section
            VStack(spacing: Spacing.md) {
                if let qrImage = generateQRCode(from: ticket.qrCodeData) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .padding(Spacing.sm)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                        .accessibilityLabel("QR code for ticket \(ticket.ticketNumber)")
                        .accessibilityHint("Show this QR code at the event entrance")
                }

                Text("Scan at entry")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)

                Text(ticket.ticketNumber)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity)
        }
        .glassCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ticket for \(event.title), \(formattedDate) at \(formattedTime), \(ticket.quantity) ticket\(ticket.quantity > 1 ? "s" : ""), \(ticket.guestName)")
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: Spacing.md) {
            ActionButton(icon: "calendar.badge.plus", title: "Calendar", color: .neonBlue) {
                addToCalendar()
            }

            ActionButton(icon: "wallet.pass", title: "Wallet", color: .gatherPrimaryText) {
                addToWallet()
            }

            ActionButton(icon: "square.and.arrow.up", title: "Share", color: .accentPurpleFallback) {
                showingShareSheet = true
            }
        }
    }

    // MARK: - Event Summary

    private var eventSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Event Details")
                .font(GatherFont.headline)

            if let location = event.location {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Color.accentPinkFallback)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.name)
                            .font(GatherFont.body)
                        if let address = location.address {
                            Text(address)
                                .font(GatherFont.caption)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                    }
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Location: \(location.name)\(location.address.map { ", \($0)" } ?? "")")
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("Order Total")
                        .foregroundStyle(Color.gatherSecondaryText)
                    Spacer()
                    Text(formatPrice(ticket.totalPrice))
                        .fontWeight(.semibold)
                }
                .font(GatherFont.callout)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Order total: \(formatPrice(ticket.totalPrice))")

                if ticket.serviceFee > 0 {
                    HStack {
                        Text("Includes 5% service fee")
                            .foregroundStyle(Color.gatherSecondaryText)
                        Spacer()
                        Text(formatPrice(ticket.serviceFee))
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                    .font(GatherFont.caption)
                }

                if ticket.discountAmount > 0 {
                    HStack {
                        Text("Discount Applied")
                            .foregroundStyle(Color.mintGreen)
                        Spacer()
                        Text("-\(formatPrice(ticket.discountAmount))")
                            .foregroundStyle(Color.mintGreen)
                    }
                    .font(GatherFont.caption)
                }

                HStack {
                    Text("Payment Method")
                        .foregroundStyle(Color.gatherSecondaryText)
                    Spacer()
                    if let method = ticket.paymentMethod {
                        Label(method.rawValue, systemImage: method.icon)
                    }
                }
                .font(GatherFont.caption)
            }
            .padding(Spacing.md)
            .glassCard(cornerRadius: CornerRadius.md)

            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(Color.accentPurpleFallback)
                Text("Your ticket has been saved to your account")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Done")
                .font(GatherFont.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient.gatherAccentGradient)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Helpers

    private var formattedDate: String {
        GatherDateFormatter.monthDayYear.string(from: event.startDate)
    }

    private var formattedTime: String {
        GatherDateFormatter.timeOnly.string(from: event.startDate)
    }

    private var ticketShareText: String {
        """
        I'm going to \(event.title)!

        \u{1F4C5} \(formattedDate) at \(formattedTime)
        \u{1F4CD} \(event.location?.name ?? "TBA")
        \u{1F3AB} Ticket #\(ticket.ticketNumber)

        Get your tickets at Gather!
        """
    }

    private func formatPrice(_ price: Decimal) -> String {
        if price == 0 { return "Free" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }

    private func addToCalendar() {
        let eventStore = EKEventStore()
        eventStore.requestFullAccessToEvents { granted, error in
            handleCalendarAccess(granted: granted, error: error, eventStore: eventStore)
        }
    }

    private func handleCalendarAccess(granted: Bool, error: Error?, eventStore: EKEventStore) {
        DispatchQueue.main.async {
            if granted {
                let calendarEvent = EKEvent(eventStore: eventStore)
                calendarEvent.title = event.title
                calendarEvent.startDate = event.startDate
                calendarEvent.endDate = event.endDate ?? event.startDate.addingTimeInterval(3600 * 2)
                calendarEvent.location = event.location?.name
                calendarEvent.notes = "Ticket: \(ticket.ticketNumber)"
                calendarEvent.calendar = eventStore.defaultCalendarForNewEvents

                do {
                    try eventStore.save(calendarEvent, span: .thisEvent)
                    calendarMessage = "Event added to your calendar!"
                } catch {
                    calendarMessage = "Could not save event: \(error.localizedDescription)"
                }
            } else {
                calendarMessage = "Calendar access denied. Please enable in Settings."
            }
            showingCalendarAlert = true
        }
    }

    private func addToWallet() {
        calendarMessage = "Wallet pass feature coming soon! Your ticket is saved in the app."
        showingCalendarAlert = true
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())

                Text(title)
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Ticket Share Sheet

struct TicketShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    let event = Event(title: "Summer Concert", startDate: Date())
    let ticket = Ticket(
        eventId: event.id,
        tierId: UUID(),
        guestName: "John Doe",
        guestEmail: "john@example.com",
        quantity: 2,
        unitPrice: 50
    )
    ticket.paymentStatus = .completed
    ticket.paymentMethod = .applePay

    return TicketConfirmationView(ticket: ticket, event: event)
}
