import SwiftUI

// MARK: - App Colors

extension Color {
    // MARK: - Primary Palette

    /// Main accent color - Purple
    static let gatherAccent = Color("AccentPurple", bundle: .main)

    /// Secondary accent - Pink
    static let gatherAccentSecondary = Color("AccentPink", bundle: .main)

    // MARK: - RSVP Status Colors

    /// Attending / Success - Green
    static let gatherSuccess = Color("RSVPYes", bundle: .main)

    /// Maybe / Warning - Amber
    static let gatherWarning = Color("RSVPMaybe", bundle: .main)

    /// Declined / Destructive - Red
    static let gatherDestructive = Color("RSVPNo", bundle: .main)

    // MARK: - Semantic Colors

    /// Primary text color
    static let gatherPrimaryText = Color(.label)

    /// Secondary text color
    static let gatherSecondaryText = Color(.secondaryLabel)

    /// Tertiary text color
    static let gatherTertiaryText = Color(.tertiaryLabel)

    /// Primary background
    static let gatherBackground = Color(.systemBackground)

    /// Secondary background (cards, grouped content)
    static let gatherSecondaryBackground = Color(.secondarySystemBackground)

    /// Tertiary background
    static let gatherTertiaryBackground = Color(.tertiarySystemBackground)

    /// Separator color
    static let gatherSeparator = Color(.separator)

    // MARK: - Fallback Colors (if asset catalog not set up)

    static let accentPurpleFallback = Color(red: 124/255, green: 58/255, blue: 237/255) // #7C3AED
    static let accentPinkFallback = Color(red: 236/255, green: 72/255, blue: 153/255)   // #EC4899
    static let rsvpYesFallback = Color(red: 16/255, green: 185/255, blue: 129/255)      // #10B981
    static let rsvpMaybeFallback = Color(red: 245/255, green: 158/255, blue: 11/255)    // #F59E0B
    static let rsvpNoFallback = Color(red: 239/255, green: 68/255, blue: 68/255)        // #EF4444
}

// MARK: - Color Scheme Helpers

extension Color {
    /// Get appropriate color based on RSVP status
    static func forRSVPStatus(_ status: RSVPStatus) -> Color {
        switch status {
        case .attending:
            return .gatherSuccess
        case .maybe:
            return .gatherWarning
        case .declined:
            return .gatherDestructive
        case .pending, .waitlisted:
            return .gatherSecondaryText
        }
    }

    /// Get appropriate color based on guest role
    static func forGuestRole(_ role: GuestRole) -> Color {
        switch role {
        case .guest:
            return .gatherSecondaryText
        case .vip:
            return .gatherWarning
        case .cohost:
            return .gatherAccent
        case .vendor:
            return .gatherAccentSecondary
        }
    }
}

// MARK: - Gradient Definitions

extension LinearGradient {
    /// Primary accent gradient
    static let gatherAccentGradient = LinearGradient(
        colors: [.accentPurpleFallback, .accentPinkFallback],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Hero overlay gradient (for text readability on images)
    static let heroOverlay = LinearGradient(
        colors: [.clear, .black.opacity(0.6)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Card shimmer gradient (for loading states)
    static let shimmer = LinearGradient(
        colors: [
            .gatherSecondaryBackground,
            .gatherTertiaryBackground,
            .gatherSecondaryBackground
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}
