import UIKit

/// Centralized haptic feedback service.
/// All haptic triggers go through this service for consistency and Mac Catalyst safety.
enum HapticService {
    // MARK: - Impact Haptics

    /// Light tap — tab switches, filter selections, chip toggles
    static func tabSwitch() {
        #if !targetEnvironment(macCatalyst)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Light tap — general button presses
    static func buttonTap() {
        #if !targetEnvironment(macCatalyst)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Medium tap — card presses, drag actions
    static func mediumImpact() {
        #if !targetEnvironment(macCatalyst)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    // MARK: - Selection Haptic

    /// Subtle tick — scrolling through pickers, selection changes
    static func selection() {
        #if !targetEnvironment(macCatalyst)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    // MARK: - Notification Haptics

    /// Success — data saved, photo uploaded, RSVP confirmed, profile saved
    static func success() {
        #if !targetEnvironment(macCatalyst)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Warning — data reset, destructive confirmation
    static func warning() {
        #if !targetEnvironment(macCatalyst)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    /// Error — validation failure, permission denied
    static func error() {
        #if !targetEnvironment(macCatalyst)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
