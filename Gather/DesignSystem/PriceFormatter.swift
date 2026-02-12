import Foundation

/// Centralized price formatting for consistent currency display across the app.
enum GatherPriceFormatter {
    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return f
    }()

    /// Formats a Decimal price as a localized currency string. Returns "Free" for zero.
    static func format(_ price: Decimal) -> String {
        if price == 0 { return "Free" }
        return currencyFormatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }

    /// Short format: integer only for whole numbers (e.g. "$25"), full for decimals (e.g. "$25.50").
    static func formatShort(_ price: Decimal) -> String {
        if price == 0 { return "Free" }
        let intVal = NSDecimalNumber(decimal: price).intValue
        if Decimal(intVal) == price {
            return "$\(intVal)"
        }
        return format(price)
    }
}
