import Foundation
import SwiftData

// MARK: - Ticket Tier

@Model
final class TicketTier {
    var id: UUID = UUID()
    var name: String = ""                    // "VIP", "General Admission", "Early Bird"
    var tierDescription: String?
    var price: Decimal = 0                   // 0 for free tickets
    var capacity: Int = 0                    // Max tickets available
    var soldCount: Int = 0                   // Tickets sold
    var minPerOrder: Int = 1
    var maxPerOrder: Int = 10
    var perks: [String] = []                 // ["Front row seating", "Meet & greet"]
    var salesStartDate: Date?
    var salesEndDate: Date?
    var isHidden: Bool = false               // For unlisted tiers (promo only)
    var sortOrder: Int = 0
    var eventId: UUID = UUID()
    var functionId: UUID?                    // Optional: tier for specific function
    var createdAt: Date = Date()

    // Computed
    var isFree: Bool { price == 0 }
    var isAvailable: Bool { remainingCount > 0 && !isSoldOut }
    var isSoldOut: Bool { soldCount >= capacity }
    var remainingCount: Int { max(0, capacity - soldCount) }

    var formattedPrice: String {
        if isFree { return "Free" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }

    var salesStatus: SalesStatus {
        let now = Date()
        if let start = salesStartDate, now < start { return .upcoming }
        if let end = salesEndDate, now > end { return .ended }
        if isSoldOut { return .soldOut }
        return .onSale
    }

    enum SalesStatus: String {
        case upcoming = "Coming Soon"
        case onSale = "On Sale"
        case soldOut = "Sold Out"
        case ended = "Sales Ended"
    }

    init(
        name: String,
        price: Decimal = 0,
        capacity: Int,
        eventId: UUID,
        functionId: UUID? = nil,
        tierDescription: String? = nil,
        perks: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.price = price
        self.capacity = capacity
        self.eventId = eventId
        self.functionId = functionId
        self.tierDescription = tierDescription
        self.perks = perks
        self.createdAt = Date()
    }
}

// MARK: - Ticket (Purchased)

@Model
final class Ticket {
    var id: UUID = UUID()
    var ticketNumber: String = ""            // "TKT-ABC123"
    var eventId: UUID = UUID()
    var tierId: UUID = UUID()
    var userId: UUID?                        // Purchaser
    var guestName: String = ""
    var guestEmail: String = ""
    var quantity: Int = 1
    var unitPrice: Decimal = 0
    var totalPrice: Decimal = 0
    var discountAmount: Decimal = 0
    var promoCodeUsed: String?
    var paymentStatusRaw: String = PaymentStatus.pending.rawValue
    var paymentMethodRaw: String?
    var serviceFee: Decimal = 0              // 5% platform fee (charged to buyer)
    var platformFee: Decimal = 0             // Same as serviceFee (platform revenue)
    var creatorPayout: Decimal = 0           // What the host receives (totalPrice - platformFee)
    var paymentId: String?                   // External payment reference
    var qrCodeData: String = ""              // For QR generation
    var isCheckedIn: Bool = false
    var checkedInAt: Date?
    var purchasedAt: Date = Date()
    var cancelledAt: Date?
    var cancellationReason: String?

    var paymentStatus: PaymentStatus {
        get { PaymentStatus(rawValue: paymentStatusRaw) ?? .pending }
        set { paymentStatusRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod? {
        get { paymentMethodRaw.flatMap { PaymentMethod(rawValue: $0) } }
        set { paymentMethodRaw = newValue?.rawValue }
    }

    // Computed
    var isValid: Bool {
        paymentStatus == .completed && cancelledAt == nil
    }

    var canCancel: Bool {
        // Free tickets can be cancelled, paid cannot (must request)
        unitPrice == 0 && cancelledAt == nil
    }

    init(
        eventId: UUID,
        tierId: UUID,
        guestName: String,
        guestEmail: String,
        quantity: Int,
        unitPrice: Decimal,
        promoCodeUsed: String? = nil,
        discountAmount: Decimal = 0
    ) {
        self.id = UUID()
        self.ticketNumber = Ticket.generateTicketNumber()
        self.eventId = eventId
        self.tierId = tierId
        self.guestName = guestName
        self.guestEmail = guestEmail
        self.quantity = quantity
        self.unitPrice = unitPrice
        let subtotal = (unitPrice * Decimal(quantity)) - discountAmount
        let fee = subtotal > 0 ? (subtotal * 5 / 100) : 0 // 5% service fee
        self.totalPrice = subtotal + fee
        self.discountAmount = discountAmount
        self.serviceFee = fee
        self.platformFee = fee
        self.creatorPayout = subtotal // Host gets full ticket price, fee is on buyer
        self.promoCodeUsed = promoCodeUsed
        self.qrCodeData = "\(eventId.uuidString):\(id.uuidString)"
        self.purchasedAt = Date()
    }

    static func generateTicketNumber() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        let numbers = "0123456789"
        let randomLetters = String((0..<3).map { _ in letters.randomElement()! })
        let randomNumbers = String((0..<4).map { _ in numbers.randomElement()! })
        return "TKT-\(randomLetters)\(randomNumbers)"
    }
}

// MARK: - Payment Enums

enum PaymentStatus: String, Codable {
    case pending = "Pending"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
    case refunded = "Refunded"
    case cancelled = "Cancelled"

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .refunded: return "arrow.uturn.backward.circle"
        case .cancelled: return "slash.circle"
        }
    }

    var color: String {
        switch self {
        case .pending: return "orange"
        case .processing: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        case .refunded: return "purple"
        case .cancelled: return "gray"
        }
    }
}

enum PaymentMethod: String, Codable {
    case applePay = "Apple Pay"
    case card = "Credit Card"
    case upi = "UPI"
    case bankTransfer = "Bank Transfer"
    case free = "Free"

    var icon: String {
        switch self {
        case .applePay: return "apple.logo"
        case .card: return "creditcard.fill"
        case .upi: return "indianrupeesign.circle"
        case .bankTransfer: return "building.columns"
        case .free: return "tag.fill"
        }
    }
}

// MARK: - Promo Code

@Model
final class PromoCode {
    var id: UUID = UUID()
    var code: String = ""                    // "EARLYBIRD20"
    var eventId: UUID = UUID()
    var discountTypeRaw: String = DiscountType.percentage.rawValue
    var discountValue: Decimal = 0           // 20 for 20% or 10.00 for $10 off

    var discountType: DiscountType {
        get { DiscountType(rawValue: discountTypeRaw) ?? .percentage }
        set { discountTypeRaw = newValue.rawValue }
    }
    var minPurchase: Decimal?                // Min order amount
    var maxDiscount: Decimal?                // Cap on discount
    var usageLimit: Int?                     // Total uses allowed
    var usageCount: Int = 0                  // Times used
    var perUserLimit: Int = 1                // Uses per user
    var validFrom: Date?
    var validUntil: Date?
    var applicableTierIds: [UUID]?           // nil = all tiers
    var isActive: Bool = true
    var createdAt: Date = Date()

    // Computed
    var isValid: Bool {
        guard isActive else { return false }
        if let limit = usageLimit, usageCount >= limit { return false }
        let now = Date()
        if let from = validFrom, now < from { return false }
        if let until = validUntil, now > until { return false }
        return true
    }

    func calculateDiscount(for amount: Decimal) -> Decimal {
        guard isValid else { return 0 }
        if let min = minPurchase, amount < min { return 0 }

        var discount: Decimal
        switch discountType {
        case .percentage:
            discount = amount * (discountValue / 100)
        case .fixed:
            discount = discountValue
        }

        if let max = maxDiscount {
            discount = min(discount, max)
        }
        return min(discount, amount) // Can't discount more than total
    }

    init(
        code: String,
        eventId: UUID,
        discountType: DiscountType,
        discountValue: Decimal,
        usageLimit: Int? = nil
    ) {
        self.id = UUID()
        self.code = code.uppercased()
        self.eventId = eventId
        self.discountType = discountType
        self.discountValue = discountValue
        self.usageLimit = usageLimit
        self.createdAt = Date()
    }
}

enum DiscountType: String, Codable {
    case percentage = "Percentage"
    case fixed = "Fixed Amount"
}

// MARK: - Waitlist Entry

@Model
final class WaitlistEntry {
    var id: UUID = UUID()
    var eventId: UUID = UUID()
    var tierId: UUID?                        // Specific tier or general
    var email: String = ""
    var name: String?
    var userId: UUID?
    var position: Int = 0
    var notifiedAt: Date?
    var convertedToTicket: Bool = false
    var createdAt: Date = Date()

    init(eventId: UUID, email: String, tierId: UUID? = nil, name: String? = nil) {
        self.id = UUID()
        self.eventId = eventId
        self.tierId = tierId
        self.email = email
        self.name = name
        self.createdAt = Date()
    }
}

// MARK: - Group Discount

struct GroupDiscount: Codable {
    var minQuantity: Int          // Buy 5+
    var discountPercent: Decimal  // Get 10% off

    static let standard: [GroupDiscount] = [
        GroupDiscount(minQuantity: 5, discountPercent: 10),
        GroupDiscount(minQuantity: 10, discountPercent: 15),
        GroupDiscount(minQuantity: 20, discountPercent: 20)
    ]

    static func discount(for quantity: Int) -> Decimal {
        let applicable = standard.filter { quantity >= $0.minQuantity }
        return applicable.max(by: { $0.discountPercent < $1.discountPercent })?.discountPercent ?? 0
    }
}
