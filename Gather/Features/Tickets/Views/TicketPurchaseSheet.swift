import SwiftUI
import SwiftData

struct TicketPurchaseSheet: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager

    // State
    @State private var selectedTiers: [UUID: Int] = [:]
    @State private var promoCode: String = ""
    @State private var appliedPromo: PromoCode?
    @State private var promoError: String?
    @State private var showPromoField = false
    @State private var guestName: String = ""
    @State private var guestEmail: String = ""
    @State private var isProcessing = false
    @State private var purchasedTicket: Ticket?
    @State private var showConfirmation = false
    @State private var paymentCompleted = false

    // MARK: - Computed

    private var sortedTiers: [TicketTier] {
        event.ticketTiers.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var totalQuantity: Int {
        selectedTiers.values.reduce(0, +)
    }

    private var subtotal: Decimal {
        sortedTiers.reduce(Decimal(0)) { total, tier in
            let qty = selectedTiers[tier.id] ?? 0
            return total + (tier.price * Decimal(qty))
        }
    }

    private var groupDiscount: Decimal {
        let discountPercent = GroupDiscount.discount(for: totalQuantity)
        return subtotal * (discountPercent / 100)
    }

    private var promoDiscount: Decimal {
        appliedPromo?.calculateDiscount(for: subtotal - groupDiscount) ?? 0
    }

    private var ticketSubtotal: Decimal {
        max(0, subtotal - groupDiscount - promoDiscount)
    }

    private var serviceFee: Decimal {
        // 5% service fee on ticket subtotal (after discounts)
        ticketSubtotal > 0 ? (ticketSubtotal * 5 / 100) : 0
    }

    private var totalPrice: Decimal {
        ticketSubtotal + serviceFee
    }

    private var isFreeOrder: Bool {
        ticketSubtotal == 0
    }

    /// This app issues free tickets only. True when every selected tier is free
    /// (or nothing is selected yet) — used to hide all money/fee/promo UI.
    private var isFreeOnlyOrder: Bool {
        let selected = sortedTiers.filter { (selectedTiers[$0.id] ?? 0) > 0 }
        return selected.allSatisfy { $0.isFree }
    }

    private var isSingleTier: Bool {
        sortedTiers.count == 1
    }

    private var mostPopularTierId: UUID? {
        sortedTiers.max(by: { $0.soldCount < $1.soldCount })?.id
    }

    private var canCheckout: Bool {
        totalQuantity > 0 && !guestName.isEmpty && !guestEmail.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Tier Selection
                        tierSection

                        // Money-only UI (promo, group discounts, order summary)
                        // is hidden entirely for free-ticket orders — this app
                        // issues free tickets only.
                        if !isFreeOnlyOrder {
                            // Promo Code
                            promoSection

                            // Group Discount Nudge
                            if totalQuantity > 0 {
                                groupDiscountInfo
                            }
                        }

                        // Your Info
                        if totalQuantity > 0 {
                            yourInfoSection
                        }

                        // Order Summary — only when there's a price to summarize
                        if totalQuantity > 0 && !isFreeOnlyOrder {
                            orderSummarySection
                        }

                        // Spacer for bottom bar
                        Color.clear.frame(height: 100)
                    }
                    .horizontalPadding()
                    .padding(.vertical)
                }
                .background(Color.gatherCanvas.ignoresSafeArea())
                .scrollDismissesKeyboard(.interactively)

                // Sticky bottom checkout bar
                VStack {
                    Spacer()
                    if totalQuantity > 0 && canCheckout {
                        checkoutBar
                    } else if totalQuantity > 0 {
                        incompleteBar
                    }
                }
                .ignoresSafeArea(.keyboard)

                // Processing overlay
                if isProcessing {
                    processingOverlay
                }
            }
            .navigationTitle("Get Free Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }
            }
            .onAppear {
                prefillUserInfo()
                // Auto-select 1 ticket for single-tier events
                if isSingleTier, let tier = sortedTiers.first, tier.isAvailable {
                    selectedTiers[tier.id] = 1
                }
            }
            .fullScreenCover(isPresented: $showConfirmation) {
                if let ticket = purchasedTicket {
                    TicketConfirmationView(ticket: ticket, event: event)
                }
            }
        }
    }

    // MARK: - Tier Selection Section

    private var tierSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if !isSingleTier {
                Text("Select Tickets")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.gatherPrimaryText)
            }

            ForEach(sortedTiers) { tier in
                TierCard(
                    tier: tier,
                    quantity: selectedTiers[tier.id] ?? 0,
                    isPopular: tier.id == mostPopularTierId && sortedTiers.count > 1,
                    onQuantityChange: { qty in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            if qty == 0 {
                                selectedTiers.removeValue(forKey: tier.id)
                            } else {
                                selectedTiers[tier.id] = qty
                            }
                        }
                    }
                )
            }
        }
    }

    // MARK: - Promo Code Section

    private var promoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let promo = appliedPromo {
                // Applied promo badge
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.rsvpYesFallback)
                    Text("\(promo.code) applied!")
                        .font(GatherFont.callout)
                        .fontWeight(.medium)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { appliedPromo = nil; promoCode = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }
                .padding(Spacing.sm)
                .background(Color.mintGreen.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))
            } else if showPromoField {
                HStack(spacing: Spacing.sm) {
                    TextField("Enter code", text: $promoCode)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.characters)
                        .submitLabel(.done)
                        .padding(Spacing.sm)
                        .background(Color.gatherElevated)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                    Button {
                        applyPromoCode()
                    } label: {
                        Text("Apply")
                            .font(GatherFont.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(promoCode.isEmpty ? Color.gatherSecondaryText : Color.accentPurpleFallback)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                    .disabled(promoCode.isEmpty)
                }

                if let error = promoError {
                    Text(error)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.rsvpNoFallback)
                }
            } else {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showPromoField = true }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "tag.fill")
                            .font(.caption)
                        Text("Have a promo code?")
                            .font(GatherFont.callout)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.accentPurpleFallback)
                }
            }
        }
    }

    // MARK: - Group Discount Info

    private var groupDiscountInfo: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            let nextDiscount = GroupDiscount.standard.first { totalQuantity < $0.minQuantity }

            if let next = nextDiscount {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text(verbatim: "Add \(next.minQuantity - totalQuantity) more for \(next.discountPercent)% off!")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .padding(Spacing.sm)
                .background(Color.accentPurpleFallback.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))
            }

            if groupDiscount > 0 {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.mintGreen)
                    Text("Group discount: -\(formatPrice(groupDiscount))")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.mintGreen)
                }
            }
        }
    }

    // MARK: - Your Info Section

    private var yourInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Your Info")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.gatherPrimaryText)
                Spacer()
                if let user = authManager.currentUser, guestName.isEmpty {
                    Button {
                        guestName = user.name
                        guestEmail = user.email ?? ""
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "person.crop.circle.fill")
                            Text("Auto-fill")
                        }
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.accentPurpleFallback)
                    }
                }
            }

            VStack(spacing: Spacing.sm) {
                TextField("Full name", text: $guestName)
                    .textFieldStyle(.plain)
                    .textContentType(.name)
                    .submitLabel(.done)
                    .padding(Spacing.sm)
                    .background(Color.gatherElevated)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                TextField("Email", text: $guestEmail)
                    .textFieldStyle(.plain)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .submitLabel(.done)
                    .padding(Spacing.sm)
                    .background(Color.gatherElevated)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            }
        }
        .padding(Spacing.md)
        .surfaceCard()
    }

    // MARK: - Order Summary Section

    private var orderSummarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Order Summary")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.gatherPrimaryText)

            // Line items
            ForEach(sortedTiers.filter { selectedTiers[$0.id] ?? 0 > 0 }) { tier in
                let qty = selectedTiers[tier.id] ?? 0
                HStack {
                    Text("\(qty)x \(tier.name)")
                        .font(GatherFont.body)
                    Spacer()
                    Text(formatPrice(tier.price * Decimal(qty)))
                        .font(GatherFont.body)
                }
            }

            Divider()

            // Subtotal
            if groupDiscount > 0 || promoDiscount > 0 {
                HStack {
                    Text("Subtotal")
                        .foregroundStyle(Color.gatherSecondaryText)
                    Spacer()
                    Text(formatPrice(subtotal))
                }
                .font(GatherFont.callout)
            }

            // Group Discount
            if groupDiscount > 0 {
                HStack {
                    Text("Group Discount")
                        .foregroundStyle(Color.mintGreen)
                    Spacer()
                    Text("-\(formatPrice(groupDiscount))")
                        .foregroundStyle(Color.mintGreen)
                }
                .font(GatherFont.callout)
            }

            // Promo Discount
            if promoDiscount > 0 {
                HStack {
                    Text("Promo: \(appliedPromo?.code ?? "")")
                        .foregroundStyle(Color.mintGreen)
                    Spacer()
                    Text("-\(formatPrice(promoDiscount))")
                        .foregroundStyle(Color.mintGreen)
                }
                .font(GatherFont.callout)
            }

            // Service Fee
            if serviceFee > 0 {
                HStack {
                    HStack(spacing: Spacing.xxs) {
                        Text("Service Fee (5%)")
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                    Spacer()
                    Text(formatPrice(serviceFee))
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .font(GatherFont.callout)
            }

            Divider()

            // Total
            HStack {
                Text("Total")
                    .font(GatherFont.headline)
                Spacer()
                Text(formatPrice(totalPrice))
                    .font(GatherFont.title2)
                    .fontWeight(.bold)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total: \(formatPrice(totalPrice))")
        }
        .padding(Spacing.md)
        .surfaceCard()
    }

    // MARK: - Checkout Bar

    private var checkoutBar: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: Spacing.sm) {
                if isFreeOrder {
                    // Free order — issues a unique ticket (QR) per claim, no payment.
                    Button {
                        completePurchase(paymentMethod: .free)
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "ticket.fill")
                            Text(totalQuantity == 1 ? "Get Free Ticket" : "Get \(totalQuantity) Free Tickets")
                        }
                        .font(GatherFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                    }
                    .accessibilityLabel("Get \(totalQuantity) free ticket\(totalQuantity == 1 ? "" : "s")")
                } else {
                    // Paid tickets - coming soon
                    VStack(spacing: Spacing.xs) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                                .font(.title3)
                                .foregroundStyle(Color.gatherSecondaryText)
                            Text("Paid tickets coming soon")
                                .font(GatherFont.headline)
                                .foregroundStyle(Color.gatherPrimaryText)
                        }
                        Text("Online payments are not yet available. Contact the event host to arrange payment.")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, Spacing.sm)
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Spacing.sm)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 15, y: -6)
            )
        }
    }

    private var incompleteBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(totalQuantity) ticket\(totalQuantity == 1 ? "" : "s")")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                    Text(isFreeOnlyOrder ? "Free" : formatPrice(totalPrice))
                        .font(GatherFont.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(isFreeOnlyOrder ? Color.rsvpYesFallback : Color.gatherPrimaryText)
                }
                Spacer()
                Text("Fill in details above")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 15, y: -6)
            )
        }
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color.accentPurpleFallback)

                Text("Issuing your ticket...")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
            }
            .padding(Spacing.xl)
            .surfaceCard()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Issuing your ticket, please wait")
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    // MARK: - Helpers

    private func prefillUserInfo() {
        if let user = authManager.currentUser {
            guestName = user.name
            guestEmail = user.email ?? ""
        }
    }

    private func formatPrice(_ price: Decimal) -> String {
        GatherPriceFormatter.format(price)
    }

    private func applyPromoCode() {
        promoError = nil
        let code = promoCode.uppercased()

        if let promo = event.promoCodes.first(where: { $0.code == code }) {
            if promo.isValid {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { appliedPromo = promo }
            } else {
                promoError = "This promo code has expired or reached its limit"
            }
        } else {
            promoError = "Invalid promo code"
        }
    }

    private func completePurchase(paymentMethod: PaymentMethod) {
        // Create tickets for each selected tier
        var lastTicket: Ticket?

        for (tierId, quantity) in selectedTiers {
            guard let tier = sortedTiers.first(where: { $0.id == tierId }), quantity > 0 else { continue }

            let discountForTier = groupDiscount + promoDiscount
            let ticket = Ticket(
                eventId: event.id,
                tierId: tierId,
                guestName: guestName,
                guestEmail: guestEmail,
                quantity: quantity,
                unitPrice: tier.price,
                promoCodeUsed: appliedPromo?.code,
                discountAmount: discountForTier
            )
            ticket.paymentStatus = .completed
            ticket.paymentMethod = paymentMethod
            ticket.userId = authManager.currentUser?.id

            // Update tier sold count
            tier.soldCount += quantity

            // Save ticket
            modelContext.insert(ticket)

            // Create transaction record
            let transaction = PaymentTransaction(
                ticketId: ticket.id,
                eventId: event.id,
                buyerAmount: ticket.totalPrice,
                ticketAmount: ticket.creatorPayout,
                serviceFeeAmount: ticket.serviceFee,
                creatorPayoutAmount: ticket.creatorPayout,
                discountAmount: discountForTier,
                paymentMethod: paymentMethod
            )
            modelContext.insert(transaction)

            lastTicket = ticket
        }

        // Update promo code usage
        if let promo = appliedPromo {
            promo.usageCount += 1
        }

        // Add as guest if not already attending
        if !event.guests.contains(where: { $0.email == guestEmail }) {
            let guest = Guest(
                name: guestName,
                email: guestEmail,
                status: .attending,
                plusOneCount: max(0, totalQuantity - 1),
                userId: authManager.currentUser?.id
            )
            event.guests.append(guest)
        }

        modelContext.safeSave()

        purchasedTicket = lastTicket
        showConfirmation = true
    }
}

// MARK: - Tier Card (Eventbrite-inspired)

struct TierCard: View {
    let tier: TicketTier
    let quantity: Int
    let isPopular: Bool
    let onQuantityChange: (Int) -> Void

    private var isSellingFast: Bool {
        !tier.isSoldOut && tier.remainingCount > 0 &&
        Double(tier.remainingCount) / Double(tier.capacity) < 0.2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Badges row
            HStack(spacing: Spacing.xs) {
                if isPopular && !tier.isSoldOut {
                    Text("POPULAR")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.sunshineYellowText)
                        .clipShape(Capsule())
                }

                if isSellingFast {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                        Text("SELLING FAST")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.warmCoral.gradient)
                    .clipShape(Capsule())
                }

                if tier.isSoldOut {
                    Text("SOLD OUT")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.gatherSecondaryText)
                        .clipShape(Capsule())
                }

                Spacer()
            }

            // Name + Price + Stepper
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.name)
                        .font(GatherFont.headline)
                        .foregroundStyle(tier.isSoldOut ? Color.gatherSecondaryText : Color.gatherPrimaryText)

                    Text(tier.formattedPrice)
                        .font(GatherFont.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(tier.isFree ? Color.mintGreen : Color.gatherPrimaryText)
                }

                Spacer()

                if tier.isAvailable {
                    // Quantity Stepper
                    HStack(spacing: Spacing.sm) {
                        Button {
                            if quantity > 0 {
                                onQuantityChange(quantity - 1)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(quantity > 0 ? Color.accentPurpleFallback : Color.gatherSecondaryText.opacity(0.3))
                        }
                        .disabled(quantity == 0)
                        .accessibilityLabel("Decrease quantity for \(tier.name)")

                        Text("\(quantity)")
                            .font(GatherFont.headline)
                            .frame(width: 30)
                            .contentTransition(.numericText())
                            .accessibilityHidden(true)

                        Button {
                            if quantity < tier.maxPerOrder && quantity < tier.remainingCount {
                                onQuantityChange(quantity + 1)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentPurpleFallback)
                        }
                        .disabled(quantity >= tier.maxPerOrder || quantity >= tier.remainingCount)
                        .accessibilityLabel("Increase quantity for \(tier.name)")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Ticket quantity for \(tier.name)")
                    .accessibilityValue("\(quantity)")
                }
            }

            // Perks
            if !tier.perks.isEmpty {
                HStack(spacing: Spacing.xs) {
                    ForEach(tier.perks.prefix(3), id: \.self) { perk in
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundStyle(Color.mintGreen)
                            Text(perk)
                                .font(GatherFont.caption)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                    }
                }
            }

            // Remaining count
            if isSellingFast {
                Text("\(tier.remainingCount) left!")
                    .font(GatherFont.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.warmCoral)
            }
        }
        .padding(Spacing.md)
        // Selected tier: accent wash over the solid card, plus accent border.
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(quantity > 0 ? Color.accentPurpleFallback.opacity(0.08) : Color.clear)
        )
        .opacity(tier.isSoldOut ? 0.6 : 1.0)
        .surfaceCard()
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .strokeBorder(
                    quantity > 0 ? Color.accentPurpleFallback : Color.clear,
                    lineWidth: 1.5
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tier.name), \(tier.formattedPrice), \(tier.isSoldOut ? "Sold out" : "\(tier.remainingCount) available")")
        .accessibilityValue(quantity > 0 ? "\(quantity) selected" : "None selected")
        .accessibilityAddTraits(quantity > 0 ? .isSelected : [])
    }
}

// MARK: - Ticket Management Sheet (Host)

/// Host-facing sheet to create and remove FREE ticket tiers on an event.
/// This app issues free tickets only, so there is no price entry — every tier
/// is locked to "Free". Each tier lists its sold / remaining counts and can be
/// deleted (which also removes it from the event's `ticketTiers` relationship).
struct TicketManagementSheet: View {
    @Bindable var event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showAddTier = false
    @State private var tierToDelete: TicketTier?

    private var sortedTiers: [TicketTier] {
        event.ticketTiers.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header

                    if sortedTiers.isEmpty {
                        GatherEmptyState(
                            icon: "ticket",
                            title: "No Ticket Tiers Yet",
                            message: "Create a free tier so guests can claim a unique ticket with its own QR code.",
                            accent: Color.forCategory(event.category)
                        )
                        .padding(.top, Spacing.xl)
                    } else {
                        VStack(spacing: Spacing.sm) {
                            ForEach(sortedTiers) { tier in
                                tierRow(tier)
                            }
                        }
                    }

                    Color.clear.frame(height: 90)
                }
                .horizontalPadding()
                .padding(.vertical)
            }
            .background(Color.gatherCanvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                addTierBar
            }
            .navigationTitle("Manage Tickets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAddTier) {
                AddTicketTierSheet(event: event)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert(
                "Delete Tier?",
                isPresented: Binding(
                    get: { tierToDelete != nil },
                    set: { if !$0 { tierToDelete = nil } }
                ),
                presenting: tierToDelete
            ) { tier in
                Button("Delete", role: .destructive) { deleteTier(tier) }
                Button("Cancel", role: .cancel) { tierToDelete = nil }
            } message: { tier in
                Text(tier.soldCount > 0
                     ? "\(tier.name) has \(tier.soldCount) ticket\(tier.soldCount == 1 ? "" : "s") already claimed. Deleting it won't cancel those tickets."
                     : "Remove \(tier.name) from this event?")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Free tickets, one QR each")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.gatherSecondaryText)
            Text("Ticket Tiers")
                .gatherSerifScreenTitle()
                .foregroundStyle(Color.gatherPrimaryText)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func tierRow(_ tier: TicketTier) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(tier.name)
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)

                    // Locked "Free" label — this app issues free tickets only.
                    Text("Free")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.rsvpYesFallback)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.rsvpYesFallback.opacity(0.15), in: Capsule())
                }

                Text("\(tier.soldCount) claimed · \(tier.remainingCount) of \(tier.capacity) left")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .contentTransition(.numericText())
            }

            Spacer()

            Button {
                tierToDelete = tier
            } label: {
                Image(systemName: "trash")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.rsvpNoFallback)
                    .frame(width: 40, height: 40)
                    .background(Color.rsvpNoFallback.opacity(0.1), in: Circle())
            }
            .accessibilityLabel("Delete \(tier.name)")
        }
        .padding(Spacing.md)
        .surfaceCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tier.name), Free, \(tier.soldCount) claimed, \(tier.remainingCount) of \(tier.capacity) remaining")
    }

    private var addTierBar: some View {
        Button {
            showAddTier = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "plus.circle.fill")
                Text("Add Free Tier")
            }
            .font(GatherFont.headline)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(LinearGradient.gatherAccentGradient)
            .clipShape(Capsule())
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Spacing.sm)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 15, y: -6)
                .ignoresSafeArea()
        )
        .accessibilityLabel("Add a free ticket tier")
    }

    private func deleteTier(_ tier: TicketTier) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            event.ticketTiers.removeAll { $0.id == tier.id }
        }
        modelContext.delete(tier)
        modelContext.safeSave()
        HapticService.success()
        tierToDelete = nil
    }
}

// MARK: - Add Ticket Tier Sheet (Host)

/// Create a single FREE ticket tier: name + capacity only. Price is fixed at
/// $0 (free) and never shown as an editable field — this app issues free
/// tickets exclusively.
struct AddTicketTierSheet: View {
    @Bindable var event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var capacityText: String = "50"

    private var capacity: Int? {
        guard let value = Int(capacityText.trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
        return value
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && capacity != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Free label — locked, not editable.
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(Color.rsvpYesFallback)
                        Text("This tier is free — guests claim a unique ticket at no cost.")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.rsvpYesFallback.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Tier Name")
                            .gatherEyebrow()
                            .foregroundStyle(Color.gatherSecondaryText)
                        TextField("e.g. General Admission", text: $name)
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .padding(Spacing.sm)
                            .background(Color.gatherElevated)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Capacity")
                            .gatherEyebrow()
                            .foregroundStyle(Color.gatherSecondaryText)
                        TextField("Number of tickets", text: $capacityText)
                            .textFieldStyle(.plain)
                            .keyboardType(.numberPad)
                            .padding(Spacing.sm)
                            .background(Color.gatherElevated)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                        Text("Guests can claim tickets until this many are gone.")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherTertiaryText)
                    }

                    // Price row — locked to Free (read-only).
                    HStack {
                        Text("Price")
                            .gatherEyebrow()
                            .foregroundStyle(Color.gatherSecondaryText)
                        Spacer()
                        Text("Free")
                            .font(GatherFont.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.rsvpYesFallback)
                    }
                    .padding(Spacing.sm)
                    .surfaceCard(cornerRadius: CornerRadius.sm)
                }
                .horizontalPadding()
                .padding(.vertical)
            }
            .background(Color.gatherCanvas.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Free Tier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTier() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func saveTier() {
        guard let capacity else { return }
        let tier = TicketTier(
            name: name.trimmingCharacters(in: .whitespaces),
            price: 0,                     // Free-only — never anything but 0.
            capacity: capacity,
            eventId: event.id
        )
        tier.sortOrder = (event.ticketTiers.map { $0.sortOrder }.max() ?? -1) + 1
        event.ticketTiers.append(tier)
        modelContext.safeSave()
        HapticService.success()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let event = Event(title: "Concert", startDate: Date())
    TicketPurchaseSheet(event: event)
        .environmentObject(AuthManager())
}
