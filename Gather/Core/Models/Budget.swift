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

    var totalPaid: Double {
        categories.flatMap { $0.expenses }.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    var totalPending: Double {
        categories.flatMap { $0.expenses }.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    var upcomingPayments: [Expense] {
        categories.flatMap { $0.expenses }
            .filter { !$0.isPaid && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
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
