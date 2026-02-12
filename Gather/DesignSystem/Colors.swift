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

    // MARK: - Warm Palette (Glassmorphism Overhaul)

    /// Warm coral - vibrant action color
    static let warmCoral = Color(red: 255/255, green: 107/255, blue: 107/255)       // #FF6B6B

    /// Sunshine yellow - highlights, badges
    static let sunshineYellow = Color(red: 251/255, green: 191/255, blue: 36/255)   // #FBBF24

    /// High-contrast yellow for text (WCAG AA on white backgrounds)
    static let sunshineYellowText = Color(red: 180/255, green: 130/255, blue: 0/255) // Darker amber

    /// Mint green - success states, free tickets
    static let mintGreen = Color(red: 52/255, green: 211/255, blue: 153/255)        // #34D399

    /// Neon blue - dark mode event cards, discovery
    static let neonBlue = Color(red: 0/255, green: 212/255, blue: 255/255)          // #00D4FF

    /// Neon pink - dark mode accents, social features
    static let neonPink = Color(red: 255/255, green: 45/255, blue: 85/255)          // #FF2D55

    /// Deep indigo - premium feel backgrounds
    static let deepIndigo = Color(red: 49/255, green: 10/255, blue: 101/255)        // #310A65

    /// Soft lavender - light glass tint
    static let softLavender = Color(red: 196/255, green: 181/255, blue: 253/255)    // #C4B5FD

    // MARK: - Glassmorphic Surface Colors

    /// Glass card light overlay (top-left)
    static let glassHighlight = Color.white.opacity(0.15)

    /// Glass card dark overlay (bottom-right)
    static let glassShadow = Color.white.opacity(0.05)

    /// Glass border highlight
    static let glassBorderTop = Color.white.opacity(0.3)

    /// Glass border shadow
    static let glassBorderBottom = Color.white.opacity(0.1)

    /// Color-scheme-aware glass border (top) — use in views with @Environment(\.colorScheme)
    static func glassBorderTopAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.3)
    }

    /// Color-scheme-aware glass border (bottom)
    static func glassBorderBottomAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.1)
    }

    // MARK: - Semantic Fallbacks

    /// Error/Destructive color
    static let gatherError = Color(red: 239/255, green: 68/255, blue: 68/255)           // #EF4444

    // MARK: - Category Gradient Colors

    // Wedding
    static let weddingRose = Color(red: 0.95, green: 0.4, blue: 0.6)
    static let weddingRoseLight = Color(red: 0.98, green: 0.6, blue: 0.7)
    static let weddingRoseDeep = Color(red: 0.9, green: 0.3, blue: 0.5)
    static let weddingRoseMid = Color(red: 0.95, green: 0.5, blue: 0.7)
    static let weddingBlush = Color(red: 1.0, green: 0.7, blue: 0.8)

    // Party
    static let partyPurple = Color(red: 0.49, green: 0.23, blue: 0.93)

    // Office
    static let officeBlue = Color(red: 0.2, green: 0.5, blue: 0.9)
    static let officeBlueLight = Color(red: 0.4, green: 0.7, blue: 1.0)
    static let officeBlueDeep = Color(red: 0.1, green: 0.4, blue: 0.85)
    static let officeBlueBright = Color(red: 0.3, green: 0.6, blue: 1.0)
    static let officeBlueSky = Color(red: 0.5, green: 0.8, blue: 1.0)

    // Conference
    static let conferenceAmber = Color(red: 0.95, green: 0.6, blue: 0.2)
    static let conferenceGold = Color(red: 1.0, green: 0.8, blue: 0.3)
    static let conferenceAmberDeep = Color(red: 0.9, green: 0.5, blue: 0.1)
    static let conferenceOrangeGold = Color(red: 1.0, green: 0.7, blue: 0.2)
    static let conferenceGoldLight = Color(red: 1.0, green: 0.85, blue: 0.4)

    // Concert
    static let concertRed = Color(red: 0.9, green: 0.2, blue: 0.3)
    static let concertSalmon = Color(red: 1.0, green: 0.4, blue: 0.5)
    static let concertRedDeep = Color(red: 0.85, green: 0.1, blue: 0.2)
    static let concertCrimson = Color(red: 0.95, green: 0.3, blue: 0.4)

    // Meetup
    static let meetupTeal = Color(red: 0.1, green: 0.7, blue: 0.5)
    static let meetupGreenLight = Color(red: 0.3, green: 0.9, blue: 0.6)
    static let meetupTealDeep = Color(red: 0.0, green: 0.6, blue: 0.45)
    static let meetupEmerald = Color(red: 0.2, green: 0.8, blue: 0.55)
    static let meetupEmeraldLight = Color(red: 0.4, green: 0.95, blue: 0.7)

    // Custom
    static let customSlate = Color(red: 0.5, green: 0.5, blue: 0.6)
    static let customSlateLight = Color(red: 0.7, green: 0.7, blue: 0.8)
    static let customSlateDark = Color(red: 0.4, green: 0.4, blue: 0.55)
    static let customSlateMid = Color(red: 0.6, green: 0.6, blue: 0.75)
    static let customSlatePale = Color(red: 0.75, green: 0.75, blue: 0.85)

    // Shared
    static let warmOrange = Color(red: 1.0, green: 0.5, blue: 0.3)
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

    /// Category-specific accent color for glass tints and badges
    static func forCategory(_ category: EventCategory) -> Color {
        switch category {
        case .wedding: return .accentPinkFallback
        case .party: return .accentPurpleFallback
        case .office: return Color(red: 0.35, green: 0.55, blue: 1.0)
        case .conference: return .sunshineYellow
        case .concert: return .warmCoral
        case .meetup: return .mintGreen
        case .custom: return .gatherSecondaryText
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

    /// Glassmorphic card fill gradient
    static let glassCardFill = LinearGradient(
        colors: [Color.glassHighlight, Color.glassShadow],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Glassmorphic border gradient
    static let glassBorder = LinearGradient(
        colors: [Color.glassBorderTop, Color.glassBorderBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Neon discovery gradient (dark mode explore)
    static let neonDiscovery = LinearGradient(
        colors: [.neonBlue, .accentPurpleFallback, .neonPink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Warm sunset gradient (featured events)
    static let warmSunset = LinearGradient(
        colors: [.warmCoral, .sunshineYellow],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Soft blue card gradient
    static let cardGradientBlue = LinearGradient(
        colors: [Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.15), Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Soft green card gradient
    static let cardGradientGreen = LinearGradient(
        colors: [Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.15), Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Soft warm/orange card gradient
    static let cardGradientOrange = LinearGradient(
        colors: [Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.15), Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Soft pink card gradient
    static let cardGradientPink = LinearGradient(
        colors: [Color(red: 0.93, green: 0.28, blue: 0.6).opacity(0.15), Color(red: 0.93, green: 0.28, blue: 0.6).opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Soft purple card gradient
    static let cardGradientPurple = LinearGradient(
        colors: [Color.partyPurple.opacity(0.15), Color.partyPurple.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Get gradient for an event category
    static func cardGradient(for category: EventCategory) -> LinearGradient {
        switch category {
        case .wedding: return cardGradientPink
        case .party: return cardGradientPurple
        case .office: return cardGradientBlue
        case .conference: return cardGradientOrange
        case .concert: return LinearGradient(
            colors: [Color.warmCoral.opacity(0.15), Color.warmCoral.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        case .meetup: return cardGradientGreen
        case .custom: return LinearGradient(
            colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.03)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        }
    }
}
