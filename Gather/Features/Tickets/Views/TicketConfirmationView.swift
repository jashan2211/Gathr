import SwiftUI
import CoreImage.CIFilterBuiltins
import EventKit
import PassKit

struct TicketConfirmationView: View {
    let ticket: Ticket
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var showingCalendarAlert = false
    @State private var calendarMessage = ""
    @State private var showConfetti = false
    @State private var cardAppeared = false
    @State private var savedToPhotos = false
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""
    @State private var photoSaver: PhotoSaver?

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
                    walletPassCard
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
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") {}
        } message: {
            Text(saveErrorMessage)
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

    // MARK: - Wallet Pass Card

    private var walletPassCard: some View {
        VStack(spacing: Spacing.md) {
            // Section header
            HStack {
                Image(systemName: "wallet.pass.fill")
                    .foregroundStyle(Color.accentPurpleFallback)
                Text("Wallet Pass")
                    .font(GatherFont.headline)
                Spacer()
                if !AppConfig.walletPassEnabled {
                    Text("Demo")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(Capsule())
                }
            }

            // Wallet-style card preview
            WalletStyleCard(
                eventTitle: event.title,
                ticketNumber: ticket.ticketNumber,
                guestName: ticket.guestName,
                date: event.startDate,
                venue: event.location?.name,
                qrCodeData: ticket.qrCodeData,
                categoryEmoji: event.category.emoji
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Wallet pass for \(event.title), ticket \(ticket.ticketNumber)")

            // Save to Photos button
            Button {
                saveWalletCardToPhotos()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: savedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .font(.body.weight(.semibold))
                    Text(savedToPhotos ? "Saved to Photos" : "Save to Photos")
                        .font(GatherFont.headline)
                }
                .foregroundStyle(savedToPhotos ? Color.mintGreen : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(
                    savedToPhotos
                        ? AnyShapeStyle(Color.mintGreen.opacity(0.15))
                        : AnyShapeStyle(LinearGradient.gatherAccentGradient)
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
            .disabled(savedToPhotos)
            .accessibilityHint(savedToPhotos ? "Card already saved" : "Saves a wallet-style card image to your photo library")

            if !AppConfig.walletPassEnabled {
                Text("Real Apple Wallet passes coming soon. Save this card to your Photos for now.")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.md)
        .glassCard(cornerRadius: CornerRadius.card)
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
        GatherPriceFormatter.format(price)
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
        if AppConfig.walletPassEnabled {
            // Future: Add real PKPass via WalletPassService
            calendarMessage = "Wallet pass added!"
            showingCalendarAlert = true
        } else {
            saveWalletCardToPhotos()
        }
    }

    private func saveWalletCardToPhotos() {
        guard !savedToPhotos else { return }

        let qrData = Data(ticket.qrCodeData.utf8)

        Task { @MainActor in
            guard let cardImage = WalletPassService.renderTicketCard(
                eventTitle: event.title,
                ticketNumber: ticket.ticketNumber,
                guestName: ticket.guestName,
                date: event.startDate,
                venue: event.location?.name,
                qrCodeData: qrData
            ) else {
                saveErrorMessage = "Could not generate wallet card image."
                showingSaveError = true
                HapticService.error()
                return
            }

            let saver = PhotoSaver()
            saver.onSuccess = { [self] in
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        savedToPhotos = true
                    }
                    HapticService.success()
                    photoSaver = nil
                }
            }
            saver.onError = { [self] error in
                DispatchQueue.main.async {
                    saveErrorMessage = error.localizedDescription
                    showingSaveError = true
                    HapticService.error()
                    photoSaver = nil
                }
            }
            // Retain saver so it isn't deallocated before the callback fires
            photoSaver = saver
            saver.saveToPhotos(image: cardImage)
        }
    }
}

// MARK: - Photo Saver Helper

private class PhotoSaver: NSObject {
    var onSuccess: (() -> Void)?
    var onError: ((Error) -> Void)?

    func saveToPhotos(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(handleSaveResult(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc private func handleSaveResult(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer?) {
        if let error {
            onError?(error)
        } else {
            onSuccess?()
        }
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

// MARK: - Wallet Style Card (Apple Wallet-inspired SwiftUI preview)

struct WalletStyleCard: View {
    let eventTitle: String
    let ticketNumber: String
    let guestName: String
    let date: Date
    let venue: String?
    let qrCodeData: String
    let categoryEmoji: String

    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(LinearGradient.gatherAccentGradient)

            // Content
            HStack(alignment: .top, spacing: 0) {
                // Left side: Event info
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // Branding
                    Text("GATHER")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1.5)

                    // Event emoji + title
                    HStack(spacing: Spacing.xs) {
                        Text(categoryEmoji)
                            .font(.system(size: 20))
                        Text(eventTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }

                    Spacer().frame(height: Spacing.xxs)

                    // Guest name
                    Label {
                        Text(guestName)
                            .font(.system(size: 12, weight: .medium))
                    } icon: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.white.opacity(0.85))

                    // Date
                    Label {
                        Text(formattedDate)
                            .font(.system(size: 12, weight: .medium))
                    } icon: {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.white.opacity(0.85))

                    // Venue
                    if let venue {
                        Label {
                            Text(venue)
                                .font(.system(size: 11, weight: .regular))
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    // Ticket number at bottom
                    Text(ticketNumber)
                        .font(.system(size: 10, design: .monospaced).weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right side: QR code
                VStack {
                    Spacer()
                    if let qrImage = generateQRCode(from: qrCodeData) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .padding(Spacing.xxs)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xs))
                    }
                    Spacer()
                }
                .padding(.trailing, Spacing.md)
            }
        }
        .frame(height: 180)
        .shadow(color: .accentPurpleFallback.opacity(0.3), radius: 12, y: 6)
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
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
