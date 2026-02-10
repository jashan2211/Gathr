import XCTest
@testable import Gather

final class TicketTests: XCTestCase {

    // MARK: - Helper Properties

    private var testEventId: UUID!
    private var testTierId: UUID!

    override func setUp() {
        super.setUp()
        testEventId = UUID()
        testTierId = UUID()
    }

    // MARK: - TicketTier Creation

    func testTicketTierCreation() {
        let tier = TicketTier(
            name: "General Admission",
            price: 25,
            capacity: 100,
            eventId: testEventId
        )

        XCTAssertFalse(tier.id.uuidString.isEmpty)
        XCTAssertEqual(tier.name, "General Admission")
        XCTAssertEqual(tier.price, 25)
        XCTAssertEqual(tier.capacity, 100)
        XCTAssertEqual(tier.soldCount, 0)
        XCTAssertEqual(tier.minPerOrder, 1)
        XCTAssertEqual(tier.maxPerOrder, 10)
        XCTAssertTrue(tier.perks.isEmpty)
        XCTAssertNil(tier.salesStartDate)
        XCTAssertNil(tier.salesEndDate)
        XCTAssertFalse(tier.isHidden)
        XCTAssertEqual(tier.sortOrder, 0)
        XCTAssertNil(tier.functionId)
    }

    func testTicketTierWithAllFields() {
        let functionId = UUID()
        let tier = TicketTier(
            name: "VIP",
            price: 150,
            capacity: 50,
            eventId: testEventId,
            functionId: functionId,
            tierDescription: "Premium experience",
            perks: ["Front row seating", "Meet & greet", "Free drinks"]
        )

        XCTAssertEqual(tier.name, "VIP")
        XCTAssertEqual(tier.price, 150)
        XCTAssertEqual(tier.capacity, 50)
        XCTAssertEqual(tier.eventId, testEventId)
        XCTAssertEqual(tier.functionId, functionId)
        XCTAssertEqual(tier.tierDescription, "Premium experience")
        XCTAssertEqual(tier.perks.count, 3)
        XCTAssertEqual(tier.perks[0], "Front row seating")
    }

    func testFreeTierCreation() {
        let tier = TicketTier(
            name: "Free Entry",
            price: 0,
            capacity: 200,
            eventId: testEventId
        )

        XCTAssertTrue(tier.isFree)
        XCTAssertEqual(tier.price, 0)
        XCTAssertEqual(tier.formattedPrice, "Free")
    }

    // MARK: - TicketTier Sold Out / Availability

    func testTierIsSoldOut() {
        let tier = TicketTier(
            name: "GA",
            price: 50,
            capacity: 10,
            eventId: testEventId
        )
        tier.soldCount = 10

        XCTAssertTrue(tier.isSoldOut)
        XCTAssertFalse(tier.isAvailable)
        XCTAssertEqual(tier.remainingCount, 0)
    }

    func testTierOverSoldStillCountsAsSoldOut() {
        let tier = TicketTier(
            name: "GA",
            price: 50,
            capacity: 10,
            eventId: testEventId
        )
        tier.soldCount = 12

        XCTAssertTrue(tier.isSoldOut)
        XCTAssertFalse(tier.isAvailable)
        XCTAssertEqual(tier.remainingCount, 0, "remainingCount should never go negative")
    }

    func testTierNotSoldOut() {
        let tier = TicketTier(
            name: "GA",
            price: 50,
            capacity: 100,
            eventId: testEventId
        )
        tier.soldCount = 50

        XCTAssertFalse(tier.isSoldOut)
        XCTAssertTrue(tier.isAvailable)
        XCTAssertEqual(tier.remainingCount, 50)
    }

    func testTierRemainingCapacity() {
        let tier = TicketTier(
            name: "GA",
            price: 25,
            capacity: 100,
            eventId: testEventId
        )

        XCTAssertEqual(tier.remainingCount, 100)

        tier.soldCount = 1
        XCTAssertEqual(tier.remainingCount, 99)

        tier.soldCount = 50
        XCTAssertEqual(tier.remainingCount, 50)

        tier.soldCount = 99
        XCTAssertEqual(tier.remainingCount, 1)

        tier.soldCount = 100
        XCTAssertEqual(tier.remainingCount, 0)
    }

    func testTierIsAvailableWhenHasRemainingCapacity() {
        let tier = TicketTier(
            name: "GA",
            price: 25,
            capacity: 5,
            eventId: testEventId
        )
        tier.soldCount = 4

        XCTAssertTrue(tier.isAvailable)
        XCTAssertEqual(tier.remainingCount, 1)
    }

    func testTierNotAvailableWhenSoldOut() {
        let tier = TicketTier(
            name: "GA",
            price: 25,
            capacity: 5,
            eventId: testEventId
        )
        tier.soldCount = 5

        XCTAssertFalse(tier.isAvailable)
    }

    // MARK: - TicketTier Sales Status

    func testSalesStatusOnSale() {
        let tier = TicketTier(
            name: "GA",
            price: 25,
            capacity: 100,
            eventId: testEventId
        )

        XCTAssertEqual(tier.salesStatus, .onSale)
    }

    func testSalesStatusUpcoming() {
        let tier = TicketTier(
            name: "GA",
            price: 25,
            capacity: 100,
            eventId: testEventId
        )
        tier.salesStartDate = Date().addingTimeInterval(86400) // Tomorrow

        XCTAssertEqual(tier.salesStatus, .upcoming)
        XCTAssertEqual(tier.salesStatus.rawValue, "Coming Soon")
    }

    func testSalesStatusEnded() {
        let tier = TicketTier(
            name: "GA",
            price: 25,
            capacity: 100,
            eventId: testEventId
        )
        tier.salesEndDate = Date().addingTimeInterval(-86400) // Yesterday

        XCTAssertEqual(tier.salesStatus, .ended)
        XCTAssertEqual(tier.salesStatus.rawValue, "Sales Ended")
    }

    func testSalesStatusSoldOut() {
        let tier = TicketTier(
            name: "GA",
            price: 25,
            capacity: 10,
            eventId: testEventId
        )
        tier.soldCount = 10

        XCTAssertEqual(tier.salesStatus, .soldOut)
        XCTAssertEqual(tier.salesStatus.rawValue, "Sold Out")
    }

    func testSalesStatusEndedTakesPrecedenceOverSoldOut() {
        let tier = TicketTier(
            name: "GA",
            price: 25,
            capacity: 10,
            eventId: testEventId
        )
        tier.soldCount = 10
        tier.salesEndDate = Date().addingTimeInterval(-86400) // Yesterday

        // "ended" is checked before "soldOut" in the salesStatus logic
        XCTAssertEqual(tier.salesStatus, .ended)
    }

    // MARK: - TicketTier Formatted Price

    func testFormattedPriceFree() {
        let tier = TicketTier(
            name: "Free",
            price: 0,
            capacity: 100,
            eventId: testEventId
        )

        XCTAssertEqual(tier.formattedPrice, "Free")
    }

    func testFormattedPricePaid() {
        let tier = TicketTier(
            name: "GA",
            price: 25,
            capacity: 100,
            eventId: testEventId
        )

        // formattedPrice uses locale currency; just verify it's not "Free"
        XCTAssertNotEqual(tier.formattedPrice, "Free")
        XCTAssertFalse(tier.formattedPrice.isEmpty)
    }

    // MARK: - TicketTier isFree

    func testIsFreeForZeroPrice() {
        let tier = TicketTier(name: "Free", price: 0, capacity: 50, eventId: testEventId)
        XCTAssertTrue(tier.isFree)
    }

    func testIsNotFreeForNonZeroPrice() {
        let tier = TicketTier(name: "Paid", price: 1, capacity: 50, eventId: testEventId)
        XCTAssertFalse(tier.isFree)
    }

    // MARK: - Ticket Creation

    func testTicketCreation() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Alice Johnson",
            guestEmail: "alice@example.com",
            quantity: 1,
            unitPrice: 50
        )

        XCTAssertFalse(ticket.id.uuidString.isEmpty)
        XCTAssertEqual(ticket.eventId, testEventId)
        XCTAssertEqual(ticket.tierId, testTierId)
        XCTAssertEqual(ticket.guestName, "Alice Johnson")
        XCTAssertEqual(ticket.guestEmail, "alice@example.com")
        XCTAssertEqual(ticket.quantity, 1)
        XCTAssertEqual(ticket.unitPrice, 50)
        XCTAssertEqual(ticket.paymentStatus, .pending)
        XCTAssertNil(ticket.paymentMethod)
        XCTAssertFalse(ticket.isCheckedIn)
        XCTAssertNil(ticket.checkedInAt)
        XCTAssertNil(ticket.cancelledAt)
        XCTAssertNil(ticket.cancellationReason)
        XCTAssertNil(ticket.promoCodeUsed)
    }

    func testTicketTotalPriceWithServiceFee() {
        // 2 tickets at $50 each = $100 subtotal
        // 5% service fee = $5
        // Total = $105
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Bob",
            guestEmail: "bob@example.com",
            quantity: 2,
            unitPrice: 50
        )

        XCTAssertEqual(ticket.unitPrice, 50)
        XCTAssertEqual(ticket.quantity, 2)
        XCTAssertEqual(ticket.serviceFee, 5)
        XCTAssertEqual(ticket.platformFee, 5)
        XCTAssertEqual(ticket.totalPrice, 105)
        XCTAssertEqual(ticket.creatorPayout, 100, "Host should receive full subtotal")
    }

    func testTicketTotalPriceWithDiscount() {
        // 2 tickets at $50 each = $100 subtotal
        // Discount of $20
        // After discount: $80
        // 5% service fee on $80 = $4
        // Total = $84
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Carol",
            guestEmail: "carol@example.com",
            quantity: 2,
            unitPrice: 50,
            discountAmount: 20
        )

        XCTAssertEqual(ticket.discountAmount, 20)
        XCTAssertEqual(ticket.serviceFee, 4)
        XCTAssertEqual(ticket.totalPrice, 84)
        XCTAssertEqual(ticket.creatorPayout, 80)
    }

    func testFreeTicketHasNoServiceFee() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Dave",
            guestEmail: "dave@example.com",
            quantity: 1,
            unitPrice: 0
        )

        XCTAssertEqual(ticket.unitPrice, 0)
        XCTAssertEqual(ticket.totalPrice, 0)
        XCTAssertEqual(ticket.serviceFee, 0)
        XCTAssertEqual(ticket.platformFee, 0)
        XCTAssertEqual(ticket.creatorPayout, 0)
    }

    func testTicketWithPromoCode() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Eve",
            guestEmail: "eve@example.com",
            quantity: 1,
            unitPrice: 100,
            promoCodeUsed: "EARLYBIRD20",
            discountAmount: 20
        )

        XCTAssertEqual(ticket.promoCodeUsed, "EARLYBIRD20")
        XCTAssertEqual(ticket.discountAmount, 20)
        // Subtotal: $100 - $20 = $80. Fee: $80 * 5% = $4. Total: $84.
        XCTAssertEqual(ticket.totalPrice, 84)
        XCTAssertEqual(ticket.serviceFee, 4)
    }

    // MARK: - Ticket Number Generation

    func testTicketNumberFormat() {
        let ticketNumber = Ticket.generateTicketNumber()

        XCTAssertTrue(ticketNumber.hasPrefix("TKT-"), "Ticket number should start with TKT-")
        XCTAssertEqual(ticketNumber.count, 11, "Ticket number should be 11 characters: TKT- + 3 letters + 4 digits")

        // Extract the random portion
        let suffix = String(ticketNumber.dropFirst(4))
        let letters = String(suffix.prefix(3))
        let numbers = String(suffix.suffix(4))

        // Verify letters are uppercase (and don't include I or O which are excluded)
        let validLetters = CharacterSet(charactersIn: "ABCDEFGHJKLMNPQRSTUVWXYZ")
        for char in letters.unicodeScalars {
            XCTAssertTrue(validLetters.contains(char), "Letter '\(char)' should be from valid set (no I or O)")
        }

        // Verify numbers are digits
        XCTAssertNotNil(Int(numbers), "Last 4 characters should be numeric digits")
    }

    func testTicketNumberUniqueness() {
        let numbers = (0..<100).map { _ in Ticket.generateTicketNumber() }
        let uniqueNumbers = Set(numbers)

        // With 24^3 * 10^4 = 138,240,000 possible combinations, 100 should all be unique
        XCTAssertEqual(numbers.count, uniqueNumbers.count, "100 generated ticket numbers should all be unique")
    }

    func testTicketHasGeneratedNumber() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Frank",
            guestEmail: "frank@example.com",
            quantity: 1,
            unitPrice: 25
        )

        XCTAssertTrue(ticket.ticketNumber.hasPrefix("TKT-"))
        XCTAssertFalse(ticket.ticketNumber.isEmpty)
    }

    // MARK: - Ticket QR Code Data

    func testTicketQRCodeData() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Grace",
            guestEmail: "grace@example.com",
            quantity: 1,
            unitPrice: 30
        )

        XCTAssertFalse(ticket.qrCodeData.isEmpty)
        XCTAssertTrue(ticket.qrCodeData.contains(testEventId.uuidString),
                       "QR code should contain the event ID")
        XCTAssertTrue(ticket.qrCodeData.contains(ticket.id.uuidString),
                       "QR code should contain the ticket ID")

        // QR format is "eventId:ticketId"
        let components = ticket.qrCodeData.split(separator: ":")
        XCTAssertEqual(components.count, 2, "QR code should have format eventId:ticketId")
    }

    // MARK: - Ticket Validity

    func testTicketIsValidWhenCompleted() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Hank",
            guestEmail: "hank@example.com",
            quantity: 1,
            unitPrice: 50
        )
        ticket.paymentStatus = .completed

        XCTAssertTrue(ticket.isValid)
    }

    func testTicketIsNotValidWhenPending() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Ivy",
            guestEmail: "ivy@example.com",
            quantity: 1,
            unitPrice: 50
        )

        XCTAssertEqual(ticket.paymentStatus, .pending)
        XCTAssertFalse(ticket.isValid)
    }

    func testTicketIsNotValidWhenCancelled() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Jack",
            guestEmail: "jack@example.com",
            quantity: 1,
            unitPrice: 50
        )
        ticket.paymentStatus = .completed
        ticket.cancelledAt = Date()

        XCTAssertFalse(ticket.isValid, "Cancelled ticket should not be valid even if payment completed")
    }

    func testTicketIsNotValidWhenFailed() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Kate",
            guestEmail: "kate@example.com",
            quantity: 1,
            unitPrice: 50
        )
        ticket.paymentStatus = .failed

        XCTAssertFalse(ticket.isValid)
    }

    func testTicketIsNotValidWhenRefunded() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Leo",
            guestEmail: "leo@example.com",
            quantity: 1,
            unitPrice: 50
        )
        ticket.paymentStatus = .refunded

        XCTAssertFalse(ticket.isValid)
    }

    // MARK: - Ticket Can Cancel

    func testFreeTicketCanCancel() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Mike",
            guestEmail: "mike@example.com",
            quantity: 1,
            unitPrice: 0
        )

        XCTAssertTrue(ticket.canCancel, "Free tickets should be cancellable")
    }

    func testPaidTicketCannotCancel() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Nina",
            guestEmail: "nina@example.com",
            quantity: 1,
            unitPrice: 50
        )

        XCTAssertFalse(ticket.canCancel, "Paid tickets should not be directly cancellable")
    }

    func testAlreadyCancelledTicketCannotCancelAgain() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Oscar",
            guestEmail: "oscar@example.com",
            quantity: 1,
            unitPrice: 0
        )
        ticket.cancelledAt = Date()

        XCTAssertFalse(ticket.canCancel, "Already cancelled ticket cannot be cancelled again")
    }

    // MARK: - Ticket Payment Status and Method

    func testPaymentStatusRawValues() {
        XCTAssertEqual(PaymentStatus.pending.rawValue, "Pending")
        XCTAssertEqual(PaymentStatus.processing.rawValue, "Processing")
        XCTAssertEqual(PaymentStatus.completed.rawValue, "Completed")
        XCTAssertEqual(PaymentStatus.failed.rawValue, "Failed")
        XCTAssertEqual(PaymentStatus.refunded.rawValue, "Refunded")
        XCTAssertEqual(PaymentStatus.cancelled.rawValue, "Cancelled")
    }

    func testPaymentStatusIcons() {
        XCTAssertEqual(PaymentStatus.pending.icon, "clock")
        XCTAssertEqual(PaymentStatus.processing.icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(PaymentStatus.completed.icon, "checkmark.circle.fill")
        XCTAssertEqual(PaymentStatus.failed.icon, "xmark.circle.fill")
        XCTAssertEqual(PaymentStatus.refunded.icon, "arrow.uturn.backward.circle")
        XCTAssertEqual(PaymentStatus.cancelled.icon, "slash.circle")
    }

    func testPaymentStatusColors() {
        XCTAssertEqual(PaymentStatus.pending.color, "orange")
        XCTAssertEqual(PaymentStatus.processing.color, "blue")
        XCTAssertEqual(PaymentStatus.completed.color, "green")
        XCTAssertEqual(PaymentStatus.failed.color, "red")
        XCTAssertEqual(PaymentStatus.refunded.color, "purple")
        XCTAssertEqual(PaymentStatus.cancelled.color, "gray")
    }

    func testPaymentMethodRawValues() {
        XCTAssertEqual(PaymentMethod.applePay.rawValue, "Apple Pay")
        XCTAssertEqual(PaymentMethod.card.rawValue, "Credit Card")
        XCTAssertEqual(PaymentMethod.upi.rawValue, "UPI")
        XCTAssertEqual(PaymentMethod.bankTransfer.rawValue, "Bank Transfer")
        XCTAssertEqual(PaymentMethod.free.rawValue, "Free")
    }

    func testPaymentMethodIcons() {
        XCTAssertEqual(PaymentMethod.applePay.icon, "apple.logo")
        XCTAssertEqual(PaymentMethod.card.icon, "creditcard.fill")
        XCTAssertEqual(PaymentMethod.upi.icon, "indianrupeesign.circle")
        XCTAssertEqual(PaymentMethod.bankTransfer.icon, "building.columns")
        XCTAssertEqual(PaymentMethod.free.icon, "tag.fill")
    }

    func testTicketPaymentStatusGetSet() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Test",
            guestEmail: "test@example.com",
            quantity: 1,
            unitPrice: 10
        )

        XCTAssertEqual(ticket.paymentStatus, .pending)

        ticket.paymentStatus = .processing
        XCTAssertEqual(ticket.paymentStatus, .processing)
        XCTAssertEqual(ticket.paymentStatusRaw, "Processing")

        ticket.paymentStatus = .completed
        XCTAssertEqual(ticket.paymentStatus, .completed)
        XCTAssertEqual(ticket.paymentStatusRaw, "Completed")
    }

    func testTicketPaymentMethodGetSet() {
        let ticket = Ticket(
            eventId: testEventId,
            tierId: testTierId,
            guestName: "Test",
            guestEmail: "test@example.com",
            quantity: 1,
            unitPrice: 10
        )

        XCTAssertNil(ticket.paymentMethod)

        ticket.paymentMethod = .applePay
        XCTAssertEqual(ticket.paymentMethod, .applePay)
        XCTAssertEqual(ticket.paymentMethodRaw, "Apple Pay")

        ticket.paymentMethod = .card
        XCTAssertEqual(ticket.paymentMethod, .card)
        XCTAssertEqual(ticket.paymentMethodRaw, "Credit Card")
    }

    // MARK: - PromoCode Creation

    func testPromoCodeCreation() {
        let promo = PromoCode(
            code: "earlybird20",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 20
        )

        XCTAssertFalse(promo.id.uuidString.isEmpty)
        XCTAssertEqual(promo.code, "EARLYBIRD20", "Code should be uppercased")
        XCTAssertEqual(promo.eventId, testEventId)
        XCTAssertEqual(promo.discountType, .percentage)
        XCTAssertEqual(promo.discountValue, 20)
        XCTAssertNil(promo.usageLimit)
        XCTAssertEqual(promo.usageCount, 0)
        XCTAssertEqual(promo.perUserLimit, 1)
        XCTAssertTrue(promo.isActive)
        XCTAssertNil(promo.minPurchase)
        XCTAssertNil(promo.maxDiscount)
        XCTAssertNil(promo.validFrom)
        XCTAssertNil(promo.validUntil)
        XCTAssertNil(promo.applicableTierIds)
    }

    func testPromoCodeWithUsageLimit() {
        let promo = PromoCode(
            code: "LIMITED50",
            eventId: testEventId,
            discountType: .fixed,
            discountValue: 10,
            usageLimit: 50
        )

        XCTAssertEqual(promo.usageLimit, 50)
        XCTAssertEqual(promo.usageCount, 0)
    }

    func testPromoCodeUppercasesCode() {
        let promo = PromoCode(
            code: "mixedCase123",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 10
        )

        XCTAssertEqual(promo.code, "MIXEDCASE123")
    }

    // MARK: - PromoCode Validation (isValid)

    func testActivePromoCodeIsValid() {
        let promo = PromoCode(
            code: "VALID",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 10
        )

        XCTAssertTrue(promo.isValid)
    }

    func testDeactivatedPromoCodeIsNotValid() {
        let promo = PromoCode(
            code: "INACTIVE",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 10
        )
        promo.isActive = false

        XCTAssertFalse(promo.isValid)
    }

    func testExpiredPromoCodeIsNotValid() {
        let promo = PromoCode(
            code: "EXPIRED",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 10
        )
        promo.validUntil = Date().addingTimeInterval(-86400) // Yesterday

        XCTAssertFalse(promo.isValid)
    }

    func testFuturePromoCodeIsNotYetValid() {
        let promo = PromoCode(
            code: "FUTURE",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 10
        )
        promo.validFrom = Date().addingTimeInterval(86400) // Tomorrow

        XCTAssertFalse(promo.isValid)
    }

    func testPromoCodeWithinDateRangeIsValid() {
        let promo = PromoCode(
            code: "INRANGE",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 10
        )
        promo.validFrom = Date().addingTimeInterval(-86400) // Yesterday
        promo.validUntil = Date().addingTimeInterval(86400) // Tomorrow

        XCTAssertTrue(promo.isValid)
    }

    func testPromoCodeExceedsUsageLimitIsNotValid() {
        let promo = PromoCode(
            code: "MAXED",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 10,
            usageLimit: 5
        )
        promo.usageCount = 5

        XCTAssertFalse(promo.isValid, "Promo should be invalid when usageCount reaches usageLimit")
    }

    func testPromoCodeBelowUsageLimitIsValid() {
        let promo = PromoCode(
            code: "BELOWLIMIT",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 10,
            usageLimit: 5
        )
        promo.usageCount = 4

        XCTAssertTrue(promo.isValid)
    }

    func testPromoCodeExceedsUsageLimitOverCount() {
        let promo = PromoCode(
            code: "OVERUSED",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 10,
            usageLimit: 3
        )
        promo.usageCount = 10

        XCTAssertFalse(promo.isValid)
    }

    func testPromoCodeNoUsageLimitWithHighUsage() {
        let promo = PromoCode(
            code: "UNLIMITED",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 10
        )
        promo.usageCount = 1000

        XCTAssertTrue(promo.isValid, "No usage limit means unlimited uses")
    }

    // MARK: - PromoCode Discount Calculation (Percentage)

    func testPercentageDiscountCalculation() {
        let promo = PromoCode(
            code: "SAVE20",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 20
        )

        let discount = promo.calculateDiscount(for: 100)
        XCTAssertEqual(discount, 20, "20% of $100 should be $20")
    }

    func testPercentageDiscountOnSmallAmount() {
        let promo = PromoCode(
            code: "SAVE50",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 50
        )

        let discount = promo.calculateDiscount(for: 10)
        XCTAssertEqual(discount, 5, "50% of $10 should be $5")
    }

    func testPercentageDiscountCannotExceedTotal() {
        let promo = PromoCode(
            code: "SAVE100PLUS",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 150 // 150%
        )

        let discount = promo.calculateDiscount(for: 50)
        XCTAssertEqual(discount, 50, "Discount cannot exceed the total amount")
    }

    func testPercentageDiscountWithMaxCap() {
        let promo = PromoCode(
            code: "CAPPED",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 20
        )
        promo.maxDiscount = 10 // Max $10 off

        let discount = promo.calculateDiscount(for: 200)
        XCTAssertEqual(discount, 10, "20% of $200 = $40, but capped at $10")
    }

    func testPercentageDiscountWithMaxCapNotHit() {
        let promo = PromoCode(
            code: "CAPPED",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 10
        )
        promo.maxDiscount = 50

        let discount = promo.calculateDiscount(for: 100)
        XCTAssertEqual(discount, 10, "10% of $100 = $10, well under $50 cap")
    }

    // MARK: - PromoCode Discount Calculation (Fixed)

    func testFixedDiscountCalculation() {
        let promo = PromoCode(
            code: "FLAT10",
            eventId: testEventId,
            discountType: .fixed,
            discountValue: 10
        )

        let discount = promo.calculateDiscount(for: 50)
        XCTAssertEqual(discount, 10, "$10 off should give $10 discount")
    }

    func testFixedDiscountCannotExceedTotal() {
        let promo = PromoCode(
            code: "FLAT100",
            eventId: testEventId,
            discountType: .fixed,
            discountValue: 100
        )

        let discount = promo.calculateDiscount(for: 30)
        XCTAssertEqual(discount, 30, "Fixed discount of $100 on $30 order should cap at $30")
    }

    func testFixedDiscountWithMaxCap() {
        let promo = PromoCode(
            code: "FLATCAPPED",
            eventId: testEventId,
            discountType: .fixed,
            discountValue: 50
        )
        promo.maxDiscount = 25

        let discount = promo.calculateDiscount(for: 100)
        XCTAssertEqual(discount, 25, "Fixed $50 discount capped at $25 max")
    }

    // MARK: - PromoCode Discount with Min Purchase

    func testDiscountWithMinPurchaseMet() {
        let promo = PromoCode(
            code: "MINMET",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 15
        )
        promo.minPurchase = 50

        let discount = promo.calculateDiscount(for: 100)
        XCTAssertEqual(discount, 15, "Min purchase of $50 met with $100 order")
    }

    func testDiscountWithMinPurchaseNotMet() {
        let promo = PromoCode(
            code: "MINNOTMET",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 15
        )
        promo.minPurchase = 50

        let discount = promo.calculateDiscount(for: 30)
        XCTAssertEqual(discount, 0, "Min purchase of $50 not met with $30 order")
    }

    func testDiscountWithMinPurchaseExact() {
        let promo = PromoCode(
            code: "MINEXACT",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 10
        )
        promo.minPurchase = 50

        let discount = promo.calculateDiscount(for: 50)
        XCTAssertEqual(discount, 5, "Exact min purchase amount should qualify")
    }

    // MARK: - PromoCode Discount Returns Zero When Invalid

    func testDiscountReturnsZeroWhenInactive() {
        let promo = PromoCode(
            code: "INACTIVE",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 20
        )
        promo.isActive = false

        let discount = promo.calculateDiscount(for: 100)
        XCTAssertEqual(discount, 0, "Inactive promo code should return 0 discount")
    }

    func testDiscountReturnsZeroWhenExpired() {
        let promo = PromoCode(
            code: "EXPIRED",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 20
        )
        promo.validUntil = Date().addingTimeInterval(-86400)

        let discount = promo.calculateDiscount(for: 100)
        XCTAssertEqual(discount, 0, "Expired promo code should return 0 discount")
    }

    func testDiscountReturnsZeroWhenUsageLimitReached() {
        let promo = PromoCode(
            code: "MAXEDOUT",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 20,
            usageLimit: 3
        )
        promo.usageCount = 3

        let discount = promo.calculateDiscount(for: 100)
        XCTAssertEqual(discount, 0, "Usage-limited promo code should return 0 when limit reached")
    }

    // MARK: - DiscountType Enum

    func testDiscountTypeRawValues() {
        XCTAssertEqual(DiscountType.percentage.rawValue, "Percentage")
        XCTAssertEqual(DiscountType.fixed.rawValue, "Fixed Amount")
    }

    func testPromoCodeDiscountTypeGetSet() {
        let promo = PromoCode(
            code: "TYPE",
            eventId: testEventId,
            discountType: .percentage,
            discountValue: 10
        )

        XCTAssertEqual(promo.discountType, .percentage)
        XCTAssertEqual(promo.discountTypeRaw, "Percentage")

        promo.discountType = .fixed
        XCTAssertEqual(promo.discountType, .fixed)
        XCTAssertEqual(promo.discountTypeRaw, "Fixed Amount")
    }

    // MARK: - GroupDiscount Standard Tiers

    func testGroupDiscountStandardTiers() {
        let tiers = GroupDiscount.standard

        XCTAssertEqual(tiers.count, 3)

        XCTAssertEqual(tiers[0].minQuantity, 5)
        XCTAssertEqual(tiers[0].discountPercent, 10)

        XCTAssertEqual(tiers[1].minQuantity, 10)
        XCTAssertEqual(tiers[1].discountPercent, 15)

        XCTAssertEqual(tiers[2].minQuantity, 20)
        XCTAssertEqual(tiers[2].discountPercent, 20)
    }

    // MARK: - GroupDiscount No Discount Under 5

    func testGroupDiscountNoDiscountForOneTicket() {
        XCTAssertEqual(GroupDiscount.discount(for: 1), 0)
    }

    func testGroupDiscountNoDiscountForTwoTickets() {
        XCTAssertEqual(GroupDiscount.discount(for: 2), 0)
    }

    func testGroupDiscountNoDiscountForThreeTickets() {
        XCTAssertEqual(GroupDiscount.discount(for: 3), 0)
    }

    func testGroupDiscountNoDiscountForFourTickets() {
        XCTAssertEqual(GroupDiscount.discount(for: 4), 0)
    }

    func testGroupDiscountNoDiscountForZero() {
        XCTAssertEqual(GroupDiscount.discount(for: 0), 0)
    }

    // MARK: - GroupDiscount 5+ = 10%

    func testGroupDiscountExactlyFiveTickets() {
        XCTAssertEqual(GroupDiscount.discount(for: 5), 10, "5 tickets should get 10% discount")
    }

    func testGroupDiscountSixTickets() {
        XCTAssertEqual(GroupDiscount.discount(for: 6), 10)
    }

    func testGroupDiscountNineTickets() {
        XCTAssertEqual(GroupDiscount.discount(for: 9), 10, "9 tickets should still be in 10% tier")
    }

    // MARK: - GroupDiscount 10+ = 15%

    func testGroupDiscountExactlyTenTickets() {
        XCTAssertEqual(GroupDiscount.discount(for: 10), 15, "10 tickets should get 15% discount")
    }

    func testGroupDiscountFifteenTickets() {
        XCTAssertEqual(GroupDiscount.discount(for: 15), 15)
    }

    func testGroupDiscountNineteenTickets() {
        XCTAssertEqual(GroupDiscount.discount(for: 19), 15, "19 tickets should still be in 15% tier")
    }

    // MARK: - GroupDiscount 20+ = 20%

    func testGroupDiscountExactlyTwentyTickets() {
        XCTAssertEqual(GroupDiscount.discount(for: 20), 20, "20 tickets should get 20% discount")
    }

    func testGroupDiscountFiftyTickets() {
        XCTAssertEqual(GroupDiscount.discount(for: 50), 20)
    }

    func testGroupDiscountOneHundredTickets() {
        XCTAssertEqual(GroupDiscount.discount(for: 100), 20)
    }

    // MARK: - GroupDiscount Boundary Tests

    func testGroupDiscountBoundaryFourToFive() {
        let fourDiscount = GroupDiscount.discount(for: 4)
        let fiveDiscount = GroupDiscount.discount(for: 5)

        XCTAssertEqual(fourDiscount, 0)
        XCTAssertEqual(fiveDiscount, 10)
        XCTAssertTrue(fiveDiscount > fourDiscount, "Discount should jump at boundary of 5")
    }

    func testGroupDiscountBoundaryNineToTen() {
        let nineDiscount = GroupDiscount.discount(for: 9)
        let tenDiscount = GroupDiscount.discount(for: 10)

        XCTAssertEqual(nineDiscount, 10)
        XCTAssertEqual(tenDiscount, 15)
        XCTAssertTrue(tenDiscount > nineDiscount, "Discount should jump at boundary of 10")
    }

    func testGroupDiscountBoundaryNineteenToTwenty() {
        let nineteenDiscount = GroupDiscount.discount(for: 19)
        let twentyDiscount = GroupDiscount.discount(for: 20)

        XCTAssertEqual(nineteenDiscount, 15)
        XCTAssertEqual(twentyDiscount, 20)
        XCTAssertTrue(twentyDiscount > nineteenDiscount, "Discount should jump at boundary of 20")
    }

    // MARK: - GroupDiscount Struct Creation

    func testGroupDiscountCreation() {
        let discount = GroupDiscount(minQuantity: 3, discountPercent: 5)

        XCTAssertEqual(discount.minQuantity, 3)
        XCTAssertEqual(discount.discountPercent, 5)
    }

    // MARK: - WaitlistEntry Creation

    func testWaitlistEntryCreation() {
        let entry = WaitlistEntry(
            eventId: testEventId,
            email: "waitlist@example.com"
        )

        XCTAssertFalse(entry.id.uuidString.isEmpty)
        XCTAssertEqual(entry.eventId, testEventId)
        XCTAssertEqual(entry.email, "waitlist@example.com")
        XCTAssertNil(entry.tierId)
        XCTAssertNil(entry.name)
        XCTAssertNil(entry.userId)
        XCTAssertEqual(entry.position, 0)
        XCTAssertNil(entry.notifiedAt)
        XCTAssertFalse(entry.convertedToTicket)
    }

    func testWaitlistEntryWithAllFields() {
        let tierId = UUID()
        let entry = WaitlistEntry(
            eventId: testEventId,
            email: "vip-waitlist@example.com",
            tierId: tierId,
            name: "Waiting Wanda"
        )

        XCTAssertEqual(entry.eventId, testEventId)
        XCTAssertEqual(entry.email, "vip-waitlist@example.com")
        XCTAssertEqual(entry.tierId, tierId)
        XCTAssertEqual(entry.name, "Waiting Wanda")
    }

    // MARK: - WaitlistEntry Position Tracking

    func testWaitlistPositionTracking() {
        let entry1 = WaitlistEntry(eventId: testEventId, email: "first@example.com")
        entry1.position = 1

        let entry2 = WaitlistEntry(eventId: testEventId, email: "second@example.com")
        entry2.position = 2

        let entry3 = WaitlistEntry(eventId: testEventId, email: "third@example.com")
        entry3.position = 3

        XCTAssertEqual(entry1.position, 1)
        XCTAssertEqual(entry2.position, 2)
        XCTAssertEqual(entry3.position, 3)
        XCTAssertTrue(entry1.position < entry2.position)
        XCTAssertTrue(entry2.position < entry3.position)
    }

    func testWaitlistNotificationTracking() {
        let entry = WaitlistEntry(eventId: testEventId, email: "notify@example.com")

        XCTAssertNil(entry.notifiedAt)

        let notificationDate = Date()
        entry.notifiedAt = notificationDate

        XCTAssertNotNil(entry.notifiedAt)
        XCTAssertEqual(entry.notifiedAt, notificationDate)
    }

    func testWaitlistConversionToTicket() {
        let entry = WaitlistEntry(eventId: testEventId, email: "convert@example.com")

        XCTAssertFalse(entry.convertedToTicket)

        entry.convertedToTicket = true

        XCTAssertTrue(entry.convertedToTicket)
    }

    func testWaitlistEntryDefaultPosition() {
        let entry = WaitlistEntry(eventId: testEventId, email: "default@example.com")

        XCTAssertEqual(entry.position, 0, "Default position should be 0 before being assigned")
    }

    // MARK: - WaitlistEntry for Specific Tier

    func testWaitlistEntryForSpecificTier() {
        let tierId = UUID()
        let entry = WaitlistEntry(
            eventId: testEventId,
            email: "tier-wait@example.com",
            tierId: tierId
        )

        XCTAssertEqual(entry.tierId, tierId)
    }

    func testWaitlistEntryForGeneralWaitlist() {
        let entry = WaitlistEntry(
            eventId: testEventId,
            email: "general-wait@example.com"
        )

        XCTAssertNil(entry.tierId, "General waitlist entry should have nil tierId")
    }
}
