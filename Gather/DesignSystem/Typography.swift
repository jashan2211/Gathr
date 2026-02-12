import SwiftUI

// MARK: - Typography System

enum GatherFont {
    // MARK: - Display Styles

    /// 34pt Bold Rounded - Screen titles, hero text
    static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)

    /// 28pt Bold Rounded - Section headers
    static let title = Font.system(.title, design: .rounded).weight(.bold)

    /// 22pt Semibold Rounded - Card titles, prominent labels
    static let title2 = Font.system(.title2, design: .rounded).weight(.semibold)

    /// 20pt Semibold Rounded - Subsection headers
    static let title3 = Font.system(.title3, design: .rounded).weight(.semibold)

    // MARK: - Body Styles

    /// 17pt Semibold - Emphasized body text, buttons
    static let headline = Font.headline

    /// 17pt Regular - Primary body text
    static let body = Font.body

    /// 16pt Regular - Secondary information
    static let callout = Font.callout

    /// 15pt Regular - Tertiary information
    static let subheadline = Font.subheadline

    /// 13pt Regular - Small labels, timestamps
    static let footnote = Font.footnote

    /// 12pt Regular - Badges, metadata
    static let caption = Font.caption

    /// 11pt Regular - Fine print
    static let caption2 = Font.caption2
}

// MARK: - Text Style Modifiers

extension View {
    /// Apply large title style
    func gatherLargeTitle() -> some View {
        self
            .font(GatherFont.largeTitle)
            .foregroundStyle(Color.gatherPrimaryText)
    }

    /// Apply title style
    func gatherTitle() -> some View {
        self
            .font(GatherFont.title)
            .foregroundStyle(Color.gatherPrimaryText)
    }

    /// Apply title2 style
    func gatherTitle2() -> some View {
        self
            .font(GatherFont.title2)
            .foregroundStyle(Color.gatherPrimaryText)
    }

    /// Apply headline style
    func gatherHeadline() -> some View {
        self
            .font(GatherFont.headline)
            .foregroundStyle(Color.gatherPrimaryText)
    }

    /// Apply body style
    func gatherBody() -> some View {
        self
            .font(GatherFont.body)
            .foregroundStyle(Color.gatherPrimaryText)
    }

    /// Apply secondary body style
    func gatherBodySecondary() -> some View {
        self
            .font(GatherFont.body)
            .foregroundStyle(Color.gatherSecondaryText)
    }

    /// Apply callout style
    func gatherCallout() -> some View {
        self
            .font(GatherFont.callout)
            .foregroundStyle(Color.gatherSecondaryText)
    }

    /// Apply caption style
    func gatherCaption() -> some View {
        self
            .font(GatherFont.caption)
            .foregroundStyle(Color.gatherTertiaryText)
    }
}

// MARK: - Accessibility Helpers

extension Font {
    /// Returns a font that respects Dynamic Type settings
    static func gatherScaled(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        Font.system(style).weight(weight)
    }
}
