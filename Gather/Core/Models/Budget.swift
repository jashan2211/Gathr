import Foundation
import SwiftData

// MARK: - Budget Model

@Model
final class Budget {
    var id: UUID
    var eventId: UUID
    var totalBudget: Double
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var categories: [BudgetCategory] = []

    @Relationship(deleteRule: .cascade)
    var splits: [PaymentSplit] = []

    init(
        id: UUID = UUID(),
        eventId: UUID,
        totalBudget: Double = 0
    ) {
        self.id = id
        self.eventId = eventId
        self.totalBudget = totalBudget
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var totalSpent: Double {
        categories.reduce(0) { $0 + $1.spent }
    }

    var totalAllocated: Double {
        categories.reduce(0) { $0 + $1.allocated }
    }

    var remaining: Double {
        totalBudget - totalSpent
    }

    var percentSpent: Double {
        guard totalBudget > 0 else { return 0 }
        return (totalSpent / totalBudget) * 100
    }

    /// Money actually handed over, including partial installments.
    var totalPaid: Double {
        categories.flatMap { $0.expenses }.reduce(0) { $0 + $1.amountPaid }
    }

    /// Money still owed across all expenses (remaining balances).
    var totalPending: Double {
        categories.flatMap { $0.expenses }.reduce(0) { $0 + $1.amountRemaining }
    }

    var upcomingPayments: [Expense] {
        categories.flatMap { $0.expenses }
            .filter { $0.paymentState != .paid && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    /// Per-vendor rollup: every expense with a vendor name, grouped with
    /// paid/owed totals — supports paying one vendor in small installments.
    var vendorSummaries: [VendorSummary] {
        let vendorExpenses = categories.flatMap { $0.expenses }.filter { ($0.vendorName ?? "").isEmpty == false }
        let grouped = Dictionary(grouping: vendorExpenses) { $0.vendorName ?? "" }
        return grouped.map { name, expenses in
            VendorSummary(
                name: name,
                total: expenses.reduce(0) { $0 + $1.amount },
                paid: expenses.reduce(0) { $0 + $1.amountPaid },
                expenseCount: expenses.count
            )
        }
        .sorted { $0.remaining > $1.remaining }
    }
}

/// Aggregated paid/owed standing with a single vendor.
struct VendorSummary: Identifiable {
    var name: String
    var total: Double
    var paid: Double
    var expenseCount: Int

    var id: String { name }
    var remaining: Double { max(0, total - paid) }
    var percentPaid: Double { total > 0 ? min(100, (paid / total) * 100) : 0 }
    var isSettled: Bool { remaining <= 0.009 }
}

// MARK: - Budget Category Model

@Model
final class BudgetCategory {
    var id: UUID
    var name: String
    var icon: String
    var allocated: Double
    var spent: Double
    var color: String
    var sortOrder: Int
    var functionId: UUID?

    @Relationship(deleteRule: .cascade)
    var expenses: [Expense] = []

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "dollarsign.circle",
        allocated: Double = 0,
        color: String = "purple",
        sortOrder: Int = 0,
        functionId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.allocated = allocated
        self.spent = 0
        self.color = color
        self.sortOrder = sortOrder
        self.functionId = functionId
    }

    var remaining: Double {
        allocated - spent
    }

    var percentSpent: Double {
        guard allocated > 0 else { return 0 }
        return (spent / allocated) * 100
    }

    var isOverBudget: Bool {
        allocated > 0 && spent > allocated
    }

    /// Source-of-truth spend, derived from the expenses themselves. The
    /// stored `spent` counter drifts when expenses are edited — call
    /// `reconcileSpent()` after any expense mutation to keep it honest.
    var totalExpensed: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var totalPaidAmount: Double {
        expenses.reduce(0) { $0 + $1.amountPaid }
    }

    func reconcileSpent() {
        spent = totalExpensed
    }
}

// MARK: - Expense Model

@Model
final class Expense {
    var id: UUID
    var name: String
    var amount: Double
    var isPaid: Bool
    var paidDate: Date?
    var dueDate: Date?
    var notes: String?
    var vendorName: String?
    var paidByName: String?
    var functionId: UUID?
    var createdAt: Date

    /// Individual payments toward this expense (installments to a vendor).
    /// Stored as an optional Codable array — an additive optional property,
    /// so existing stores lightweight-migrate without a new schema version.
    var payments: [ExpensePayment]?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        isPaid: Bool = false,
        paidDate: Date? = nil,
        dueDate: Date? = nil,
        notes: String? = nil,
        vendorName: String? = nil,
        paidByName: String? = nil,
        functionId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.isPaid = isPaid
        self.paidDate = paidDate
        self.dueDate = dueDate
        self.notes = notes
        self.vendorName = vendorName
        self.paidByName = paidByName
        self.functionId = functionId
        self.createdAt = Date()
    }
}

// MARK: - Expense Payment (installments)

/// One payment toward an expense — e.g. a deposit, then the balance later.
struct ExpensePayment: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var amount: Double
    var date: Date
    var method: String?
    var note: String?
    /// Who made this payment — enables multiple people paying different amounts
    /// toward one expense (e.g. Designer $3000: Simar $2000, Jashan $1000).
    /// Optional so older stored payments decode as `nil` (no migration needed).
    var paidByName: String?

    init(id: UUID = UUID(), amount: Double, date: Date = Date(), method: String? = nil, note: String? = nil, paidByName: String? = nil) {
        self.id = id
        self.amount = amount
        self.date = date
        self.method = method
        self.note = note
        self.paidByName = paidByName
    }
}

/// Payment progress of an expense.
enum ExpensePaymentState {
    case unpaid
    case partial
    case paid

    var displayName: String {
        switch self {
        case .unpaid: return "Unpaid"
        case .partial: return "Partially Paid"
        case .paid: return "Paid"
        }
    }
}

extension Expense {
    /// Half a cent — Double money sums leave ~1e-16 residues (e.g. 0.40 + 1.44
    /// vs 1.84), which would strand an expense at "Partially Paid, $0.00 left".
    private static let centTolerance = 0.005

    /// Recorded installment payments, oldest first. Legacy expenses marked
    /// paid before installments existed count as one full payment with an id
    /// derived from the expense so SwiftUI row identity stays stable.
    var recordedPayments: [ExpensePayment] {
        if let payments, !payments.isEmpty {
            return payments.sorted { $0.date < $1.date }
        }
        if isPaid {
            return [ExpensePayment(id: id, amount: amount, date: paidDate ?? createdAt, note: nil)]
        }
        return []
    }

    /// Total recorded so far. Not capped — overpayment is prevented at the
    /// recording UI, and an honest sum keeps the ledger auditable.
    var amountPaid: Double {
        if let payments, !payments.isEmpty {
            return payments.reduce(0) { $0 + $1.amount }
        }
        return isPaid ? amount : 0
    }

    var amountRemaining: Double {
        let remaining = amount - amountPaid
        return remaining < Self.centTolerance ? 0 : remaining
    }

    var paymentState: ExpensePaymentState {
        if amountPaid < Self.centTolerance { return .unpaid }
        return (amount - amountPaid) < Self.centTolerance ? .paid : .partial
    }

    var percentPaid: Double {
        guard amount > 0 else { return 0 }
        return min(100, (amountPaid / amount) * 100)
    }

    /// Records an installment and keeps the legacy `isPaid`/`paidDate`
    /// fields in sync so older UI and Firestore sync stay correct.
    func recordPayment(amount paymentAmount: Double, date: Date = Date(), method: String? = nil, note: String? = nil, paidByName: String? = nil) {
        var list = payments ?? []
        // Migrate a legacy full payment into the list before appending.
        if list.isEmpty && isPaid {
            list.append(ExpensePayment(amount: amount, date: paidDate ?? createdAt, paidByName: self.paidByName))
        }
        // Model-level guard: never let recorded payments exceed the expense
        // amount, so a stray call (or a legacy already-paid expense) can't push
        // the total negative and corrupt settle-up / progress math.
        let alreadyRecorded = list.reduce(0) { $0 + $1.amount }
        let room = max(0, amount - alreadyRecorded)
        let clamped = min(max(0, paymentAmount), room)
        if clamped >= Self.centTolerance {
            list.append(ExpensePayment(amount: clamped, date: date, method: method, note: note, paidByName: paidByName))
        }
        payments = list.isEmpty ? nil : list
        syncLegacyPaidFlags()
    }

    /// Amount paid grouped by payer, largest first — powers the "who paid what"
    /// contributions breakdown on an expense.
    var contributionsByPayer: [(name: String, amount: Double)] {
        let named = recordedPayments.filter { !($0.paidByName ?? "").isEmpty }
        let grouped = Dictionary(grouping: named) { $0.paidByName ?? "" }
            .map { (name: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
        return grouped.sorted { $0.amount > $1.amount }
    }

    func removePayment(id paymentId: UUID) {
        guard var list = payments else { return }
        list.removeAll { $0.id == paymentId }
        payments = list
        syncLegacyPaidFlags()
    }

    /// One-tap full settle: records the outstanding balance as a payment.
    func markFullyPaid(date: Date = Date()) {
        if amountRemaining >= Self.centTolerance {
            recordPayment(amount: amountRemaining, date: date)
        } else {
            resyncPaidFlags()
        }
    }

    func markUnpaid() {
        payments = []
        isPaid = false
        paidDate = nil
    }

    /// Re-derives the legacy `isPaid`/`paidDate` flags. Must read the STORED
    /// payments list, not `amountPaid` — after removing the last payment,
    /// `amountPaid`'s legacy fallback would consult the stale `isPaid` flag
    /// and resurrect a phantom full payment.
    func resyncPaidFlags() {
        let paid = (payments ?? []).reduce(0) { $0 + $1.amount }
        if payments == nil {
            // No installment list — legacy flags stay authoritative.
            paidDate = isPaid ? (paidDate ?? createdAt) : nil
            return
        }
        isPaid = amount > 0 && (amount - paid) < Self.centTolerance
        paidDate = isPaid ? recordedPayments.last?.date : nil
    }

    private func syncLegacyPaidFlags() {
        resyncPaidFlags()
    }
}

// MARK: - Default Categories

extension BudgetCategory {
    static let weddingDefaults: [(name: String, icon: String, color: String)] = [
        ("Venue", "building.2", "purple"),
        ("Catering", "fork.knife", "pink"),
        ("Photography", "camera", "blue"),
        ("Flowers", "leaf", "green"),
        ("Music/DJ", "music.note", "orange"),
        ("Attire", "tshirt", "indigo"),
        ("Invitations", "envelope", "teal"),
        ("Decorations", "sparkles", "yellow"),
        ("Transportation", "car", "gray"),
        ("Miscellaneous", "ellipsis.circle", "secondary")
    ]

    static let partyDefaults: [(name: String, icon: String, color: String)] = [
        ("Venue", "building.2", "purple"),
        ("Food & Drinks", "fork.knife", "pink"),
        ("Decorations", "sparkles", "yellow"),
        ("Entertainment", "music.note", "orange"),
        ("Favors", "gift", "teal")
    ]

    static let sportsDefaults: [(name: String, icon: String, color: String)] = [
        ("Venue/Field", "sportscourt", "green"),
        ("Equipment", "duffle.bag", "blue"),
        ("Food & Drinks", "fork.knife", "pink"),
        ("Uniforms/Gear", "tshirt", "indigo"),
        ("Transportation", "car", "gray"),
        ("Miscellaneous", "ellipsis.circle", "secondary")
    ]

    static let casualDefaults: [(name: String, icon: String, color: String)] = [
        ("Food", "fork.knife", "pink"),
        ("Drinks", "cup.and.saucer", "blue"),
        ("Supplies", "bag", "orange"),
        ("Miscellaneous", "ellipsis.circle", "secondary")
    ]

    static func createDefaultCategories() -> [BudgetCategory] {
        weddingDefaults.enumerated().map { index, item in
            BudgetCategory(
                name: item.name,
                icon: item.icon,
                color: item.color,
                sortOrder: index
            )
        }
    }

    static func createDefaultCategories(for category: EventCategory) -> [BudgetCategory] {
        let defaults: [(name: String, icon: String, color: String)]
        switch category {
        case .wedding:
            defaults = weddingDefaults
        case .party:
            defaults = partyDefaults
        case .sports:
            defaults = sportsDefaults
        default:
            defaults = casualDefaults
        }
        return defaults.enumerated().map { index, item in
            BudgetCategory(
                name: item.name,
                icon: item.icon,
                color: item.color,
                sortOrder: index
            )
        }
    }
}

// MARK: - Currency Formatting

extension Double {
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
}
