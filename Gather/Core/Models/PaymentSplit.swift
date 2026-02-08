import Foundation
import SwiftData

// MARK: - Payment Split Model

@Model
final class PaymentSplit {
    var id: UUID
    var name: String
    var email: String?
    var shareAmount: Double
    var paidAmount: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        email: String? = nil,
        shareAmount: Double = 0,
        paidAmount: Double = 0
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.shareAmount = shareAmount
        self.paidAmount = paidAmount
        self.createdAt = Date()
    }

    var isPaidUp: Bool {
        paidAmount >= shareAmount
    }

    var owedAmount: Double {
        max(0, shareAmount - paidAmount)
    }
}
