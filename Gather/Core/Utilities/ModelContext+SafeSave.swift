import SwiftData
import os

private let logger = Logger(subsystem: "ca.thebighead.gathr", category: "SwiftData")

extension ModelContext {
    /// Saves changes with error logging instead of silently swallowing failures.
    /// SwiftData auto-saves periodically, so a failed explicit save is non-fatal
    /// but should be logged for debugging.
    @discardableResult
    func safeSave() -> Bool {
        do {
            try save()
            return true
        } catch {
            logger.error("ModelContext save failed: \(error.localizedDescription)")
            return false
        }
    }
}
