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

                // Serif display moment — the editorial signature
                Text("Tickets")
                    .gatherSerifScreenTitle()
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

/// A REAL ticket: surface card clipped to the signature `TicketShape` with a
/// dashed `TicketPerforation` tear line. The left stub carries the QR code
/// (light backing for scannability) and date; the body carries the event
/// title and meta.
private struct TicketCard: View {
    let ticket: Ticket
    let event: Event?

    @Environment(\.colorScheme) private var colorScheme

    private static let stubFraction: CGFloat = 0.3

    private var category: EventCategory {
        event?.category ?? .custom
    }

    private var ticketSilhouette: TicketShape {
        TicketShape(cornerRadius: 18, notchRadius: 8, stubFraction: Self.stubFraction)
    }

    var body: some View {
        TicketSplitLayout(stubFraction: Self.stubFraction) {
            stub
            content
        }
        .background(Color.gatherSurface)
        .clipShape(ticketSilhouette)
        .overlay(TicketPerforation(stubFraction: Self.stubFraction))
        .overlay(
            ticketSilhouette
                .stroke(
                    Color.white.opacity(colorScheme == .dark ? 0.06 : 0),
                    lineWidth: 1
                )
        )
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0 : 0.05),
            radius: 8, y: 4
        )
    }

    // MARK: Stub — QR + date (the tear-off half)

    private var stub: some View {
        VStack(spacing: Spacing.xs) {
            // QR code on a light backing so the code stays scannable
            if let qrImage = generateQRCode(from: ticket.qrCodeData) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .padding(6)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))
                    .accessibilityLabel("Ticket QR code")
            }

            if let event {
                VStack(spacing: 0) {
                    Text(event.startDate.formatted(.dateTime.month(.abbreviated)).uppercased())
                        .gatherEyebrow()
                        .foregroundStyle(Color.gatherSecondaryText)
                    Text(event.startDate.formatted(.dateTime.day()))
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Color.gatherPrimaryText)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.forCategory(category).opacity(0.10))
    }

    // MARK: Body — event title + meta + details

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .top) {
                Text(category.emoji)
                    .font(.system(size: 22))
                Spacer()
                statusBadge
            }

            Text(event?.title ?? "Event")
                .font(.system(size: 18, weight: .bold))
                .kerning(-0.3)
                .foregroundStyle(Color.gatherPrimaryText)
                .lineLimit(2)

            if let event {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .bold))
                    Text(GatherDateFormatter.fullEventDate.string(from: event.startDate))
                        .gatherMetaText()
                        .lineLimit(1)
                }
                .foregroundStyle(Color.gatherSecondaryText)

                if let location = event.location {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11, weight: .bold))
                        Text(location.name)
                            .gatherMetaText()
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.gatherSecondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ticketDetail(label: "Ticket", value: ticket.ticketNumber)
                ticketDetail(label: "Guest", value: ticket.guestName)
                ticketDetail(label: "Qty", value: "\(ticket.quantity)")
                if ticket.totalPrice > 0 {
                    ticketDetail(label: "Total", value: GatherPriceFormatter.format(ticket.totalPrice))
                } else {
                    ticketDetail(label: "Total", value: "Free")
                }
            }
            .padding(.top, Spacing.xxs)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: ticket.paymentStatus.icon)
                .font(.caption2)
            Text(ticket.paymentStatus.rawValue)
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundStyle(Color.forCategory(category))
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 4)
        .background(Color.forCategory(category).opacity(0.15), in: Capsule())
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

// MARK: - Ticket Split Layout

/// Splits exactly two children at `stubFraction` of the available width so the
/// stub content lines up with the `TicketShape` notches and the
/// `TicketPerforation` tear line at any card width.
/// (Qualified as `SwiftUI.Layout` — the app's `Layout` token enum shadows the
/// protocol name.)
private struct TicketSplitLayout: SwiftUI.Layout {
    var stubFraction: CGFloat = 0.3

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = proposal.width ?? 320
        let stubWidth = width * stubFraction
        let stubHeight = subviews[0].sizeThatFits(ProposedViewSize(width: stubWidth, height: nil)).height
        let bodyHeight = subviews[1].sizeThatFits(ProposedViewSize(width: width - stubWidth, height: nil)).height
        return CGSize(width: width, height: max(stubHeight, bodyHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let stubWidth = bounds.width * stubFraction
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: stubWidth, height: bounds.height)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + stubWidth, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width - stubWidth, height: bounds.height)
        )
    }
}

#Preview {
    NavigationStack {
        MyTicketsView()
            .modelContainer(for: [Ticket.self, Event.self], inMemory: true)
    }
}
