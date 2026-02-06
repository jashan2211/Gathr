import SwiftUI

// MARK: - Spacing System

enum Spacing {
    /// 4pt - Minimal spacing
    static let xxs: CGFloat = 4

    /// 8pt - Tight spacing
    static let xs: CGFloat = 8

    /// 12pt - Compact spacing
    static let sm: CGFloat = 12

    /// 16pt - Default spacing
    static let md: CGFloat = 16

    /// 24pt - Comfortable spacing
    static let lg: CGFloat = 24

    /// 32pt - Generous spacing
    static let xl: CGFloat = 32

    /// 48pt - Section spacing
    static let xxl: CGFloat = 48

    /// 64pt - Hero spacing
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius

enum CornerRadius {
    /// 4pt - Subtle rounding
    static let xs: CGFloat = 4

    /// 8pt - Small elements
    static let sm: CGFloat = 8

    /// 12pt - Medium elements
    static let md: CGFloat = 12

    /// 16pt - Cards, containers
    static let lg: CGFloat = 16

    /// 24pt - Large cards, sheets
    static let xl: CGFloat = 24

    /// 32pt - Full rounding for pills
    static let full: CGFloat = 32
}

// MARK: - Icon Sizes

enum IconSize {
    /// 16pt - Inline icons
    static let sm: CGFloat = 16

    /// 20pt - Button icons
    static let md: CGFloat = 20

    /// 24pt - Standard icons
    static let lg: CGFloat = 24

    /// 32pt - Feature icons
    static let xl: CGFloat = 32

    /// 48pt - Hero icons
    static let xxl: CGFloat = 48
}

// MARK: - Avatar Sizes

enum AvatarSize {
    /// 24pt - Inline, compact
    static let xs: CGFloat = 24

    /// 32pt - List items
    static let sm: CGFloat = 32

    /// 40pt - Standard
    static let md: CGFloat = 40

    /// 56pt - Prominent
    static let lg: CGFloat = 56

    /// 80pt - Profile
    static let xl: CGFloat = 80

    /// 120pt - Hero
    static let xxl: CGFloat = 120
}

// MARK: - Layout Constants

enum Layout {
    /// Horizontal padding for screen edges
    static let horizontalPadding: CGFloat = Spacing.md

    /// Minimum touch target size (44pt Apple HIG)
    static let minTouchTarget: CGFloat = 44

    /// Bottom tab bar height
    static let tabBarHeight: CGFloat = 83

    /// Navigation bar height
    static let navBarHeight: CGFloat = 44

    /// Bottom sheet handle height
    static let sheetHandleHeight: CGFloat = 20

    /// Card minimum height
    static let cardMinHeight: CGFloat = 80

    /// Hero image height
    static let heroImageHeight: CGFloat = 280

    /// Compact hero height
    static let heroImageHeightCompact: CGFloat = 200
}

// MARK: - Padding Helpers

extension View {
    /// Apply standard horizontal padding
    func horizontalPadding() -> some View {
        self.padding(.horizontal, Layout.horizontalPadding)
    }

    /// Apply standard card padding
    func cardPadding() -> some View {
        self.padding(Spacing.md)
    }

    /// Apply section spacing
    func sectionSpacing() -> some View {
        self.padding(.vertical, Spacing.lg)
    }
}
