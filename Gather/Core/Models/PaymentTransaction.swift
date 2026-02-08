import Foundation
import SwiftData

// MARK: - Payment Transaction (fee tracking)

@Model
final class PaymentTransaction {
    var id: UUID = UUID()
    var ticketId: UUID = UUID()
    var eventId: UUID = UUID()
    var buyerAmount: Decimal = 0         // Total buyer pays (ticket + service fee)
    var ticketAmount: Decimal = 0        // Ticket price before fees
    var serviceFeeAmount: Decimal = 0    // 5% service fee (platform revenue)
    var creatorPayoutAmount: Decimal = 0 // What the host receives
    var discountAmount: Decimal = 0      // Any discounts applied
    var paymentMethodRaw: String?
    var statusRaw: String = TransactionStatus.completed.rawValue
    var stripePaymentIntentId: String?   // For production Stripe integration
    var createdAt: Date = Date()

    var paymentMethod: PaymentMethod? {
        get { paymentMethodRaw.flatMap { PaymentMethod(rawValue: $0) } }
        set { paymentMethodRaw = newValue?.rawValue }
    }

    var status: TransactionStatus {
        get { TransactionStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    init(
        ticketId: UUID,
        eventId: UUID,
        buyerAmount: Decimal,
        ticketAmount: Decimal,
        serviceFeeAmount: Decimal,
        creatorPayoutAmount: Decimal,
        discountAmount: Decimal = 0,
        paymentMethod: PaymentMethod?
    ) {
        self.id = UUID()
        self.ticketId = ticketId
        self.eventId = eventId
        self.buyerAmount = buyerAmount
        self.ticketAmount = ticketAmount
        self.serviceFeeAmount = serviceFeeAmount
        self.creatorPayoutAmount = creatorPayoutAmount
        self.discountAmount = discountAmount
        self.paymentMethodRaw = paymentMethod?.rawValue
        self.createdAt = Date()
    }
}

enum TransactionStatus: String, Codable {
    case pending = "Pending"
    case completed = "Completed"
    case refunded = "Refunded"
    case failed = "Failed"
}
