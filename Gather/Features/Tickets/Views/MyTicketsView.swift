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
                VStack(spacing: Spacing.md) {
                    if !validTickets.isEmpty {
                        ForEach(validTickets) { ticket in
                            TicketCard(ticket: ticket, event: event(for: ticket))
                        }
                    }

                    if !cancelledTickets.isEmpty {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "archivebox")
                                .font(.caption)
                                .foregroundStyle(Color.gatherSecondaryText)
                            Text("Past / Cancelled")
                                .font(GatherFont.headline)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Spacing.sm)

                        ForEach(cancelledTickets) { ticket in
                            TicketCard(ticket: ticket, event: event(for: ticket))
                                .opacity(0.6)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("My Tickets")
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
                .frame(height: 80)

            ZStack {
                Circle()
                    .fill(Color.accentPurpleFallback.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "ticket")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accentPurpleFallback)
            }

            Text("No Tickets Yet")
                .font(GatherFont.title3)
                .foregroundStyle(Color.gatherPrimaryText)

            Text("Tickets you purchase will appear here with QR codes for easy check-in.")
                .font(GatherFont.body)
                .foregroundStyle(Color.gatherSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
    }
}

// MARK: - Ticket Card

private struct TicketCard: View {
    let ticket: Ticket
    let event: Event?

    var body: some View {
        VStack(spacing: 0) {
            // Header with event info
            HStack(spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .fill(LinearGradient.categoryGradientVibrant(for: event?.category ?? .custom))
                        .frame(width: 44, height: 44)
                    Text(event?.category.emoji ?? "🎫")
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(event?.title ?? "Event")
                        .font(GatherFont.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .lineLimit(1)

                    if let event {
                        Text(GatherDateFormatter.fullEventDate.string(from: event.startDate))
                            .font(.caption2)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }

                Spacer()

                // Status
                statusBadge
            }
            .padding(Spacing.md)

            // Dashed divider
            DashedDivider()
                .padding(.horizontal, Spacing.sm)

            // QR Code + Ticket details
            HStack(spacing: Spacing.md) {
                // QR Code
                if let qrImage = generateQRCode(from: ticket.qrCodeData) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
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
        .glassCard()
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: ticket.paymentStatus.icon)
                .font(.caption2)
            Text(ticket.paymentStatus.rawValue)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch ticket.paymentStatus {
        case .completed: return Color.rsvpYesFallback
        case .pending, .processing: return Color.rsvpMaybeFallback
        case .failed, .cancelled: return Color.rsvpNoFallback
        case .refunded: return Color.accentPurpleFallback
        }
    }

    private func ticketDetail(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(GatherFont.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.gatherPrimaryText)
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
            .foregroundStyle(Color.gatherSecondaryText.opacity(0.3))
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
