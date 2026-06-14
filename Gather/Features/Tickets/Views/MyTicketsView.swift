import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

struct MyTicketsView: View {
    @Query(sort: \Ticket.purchasedAt, order: .reverse) private var allTickets: [Ticket]
    @Query private var allEvents: [Event]

    private var validTickets: [Ticket] {
        allTickets.filter { $0.paymentStatus == .completed && $0.cancelledAt == nil }
    }

    private var cancelledTickets: [Ticket] {
        allTickets.filter { $0.cancelledAt != nil || $0.paymentStatus == .cancelled }
    }

    private func event(for ticket: Ticket) -> Event? {
        allEvents.first { $0.id == ticket.eventId }
    }

    var body: some View {
        ScrollView {
            if allTickets.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    header

                    if !validTickets.isEmpty {
                        ForEach(validTickets) { ticket in
                            TicketCard(ticket: ticket, event: event(for: ticket))
                        }
                    }

                    if !cancelledTickets.isEmpty {
                        Text("PAST / CANCELLED")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Spacing.sm)

                        ForEach(cancelledTickets) { ticket in
                            TicketCard(ticket: ticket, event: event(for: ticket))
                                .opacity(0.6)
                        }
                    }
                }
                .horizontalPadding()
                .padding(.vertical)
            }
        }
        .background(Color.gatherCanvas.ignoresSafeArea())
        .navigationTitle("My Tickets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Editorial Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Your QR codes, ready to scan")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.gatherSecondaryText)

                Text("Tickets")
                    .font(.system(size: 34, weight: .heavy))
                    .kerning(-1)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer()

            if !validTickets.isEmpty {
                Text("\(validTickets.count) active")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentPurpleFallback)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .background(Color.gatherSurface, in: Capsule())
            }
        }
        .padding(.bottom, Spacing.xs)
    }

    private var emptyState: some View {
        GatherEmptyState(
            icon: "ticket",
            title: "No Tickets Yet",
            message: "Tickets you grab will land here, QR codes ready for check-in."
        )
        .padding(.top, 80)
    }
}

// MARK: - Ticket Card

private struct TicketCard: View {
    let ticket: Ticket
    let event: Event?

    private var category: EventCategory {
        event?.category ?? .custom
    }

    var body: some View {
        VStack(spacing: 0) {
            // Poster header: category gradient band with bold event title
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top) {
                    Text(category.emoji)
                        .font(.system(size: 30))
                    Spacer()
                    statusBadge
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(event?.title ?? "Event")
                        .font(.system(size: 22, weight: .heavy))
                        .kerning(-0.5)
                        .foregroundStyle(Color.onCategory(category))
                        .lineLimit(2)

                    if let event {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11, weight: .bold))
                            Text(GatherDateFormatter.fullEventDate.string(from: event.startDate))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color.onCategory(category).opacity(0.85))

                        if let location = event.location {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 11, weight: .bold))
                                Text(location.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Color.onCategory(category).opacity(0.85))
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color.forCategory(category),
                        Color.forCategory(category).opacity(0.78)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Perforated stub divider
            DashedDivider()
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)

            // QR Code + Ticket details
            HStack(spacing: Spacing.md) {
                // QR Code on a light backing so the code stays scannable
                if let qrImage = generateQRCode(from: ticket.qrCodeData) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .padding(Spacing.xs)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ticketDetail(label: "Ticket", value: ticket.ticketNumber)
                    ticketDetail(label: "Guest", value: ticket.guestName)
                    ticketDetail(label: "Qty", value: "\(ticket.quantity)")
                    if ticket.totalPrice > 0 {
                        ticketDetail(label: "Total", value: GatherPriceFormatter.format(ticket.totalPrice))
                    } else {
                        ticketDetail(label: "Total", value: "Free")
                    }
                }

                Spacer()
            }
            .padding(Spacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .surfaceCard()
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: ticket.paymentStatus.icon)
                .font(.caption2)
            Text(ticket.paymentStatus.rawValue)
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundStyle(Color.onCategory(category))
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 4)
        .background(Color.onCategory(category).opacity(0.18), in: Capsule())
    }

    private func ticketDetail(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.gatherSecondaryText)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.gatherPrimaryText)
                .lineLimit(1)
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scale = 240 / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Dashed Divider

private struct DashedDivider: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .foregroundStyle(Color.gatherSecondaryText.opacity(0.4))
        }
        .frame(height: 1)
    }
}

#Preview {
    NavigationStack {
        MyTicketsView()
            .modelContainer(for: [Ticket.self, Event.self], inMemory: true)
    }
}
