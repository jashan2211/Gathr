import SwiftUI

// MARK: - Typography System

enum GatherFont {
    // MARK: - Display Styles

    /// 34pt Heavy SF Pro Display - Screen titles, hero text.
    /// Editorial weight (was Rounded/Bold) for a more premium, less "toy" feel.
    /// Pair with `.kerning(-0.5)` via `gatherLargeTitle()` (critique §3).
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.heavy)

    /// 28pt Heavy SF Pro Display - Section headers
    static let title = Font.system(.title, design: .default).weight(.heavy)

    /// 22pt Bold - Card titles, prominent labels.
    /// Default (not Rounded) design: Rounded headers read as "toy"; standard
    /// SF Pro Display at bold keeps the editorial, premium tone (critique §3).
    static let title2 = Font.system(.title2, design: .default).weight(.bold)

    /// 20pt Semibold - Subsection headers
    static let title3 = Font.system(.title3, design: .default).weight(.semibold)

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
            .kerning(-0.5)
            .foregroundStyle(Color.gatherPrimaryText)
    }

    /// Apply title style
    func gatherTitle() -> some View {
        self
            .font(GatherFont.title)
            .kerning(-0.4)
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

// MARK: - Editorial Scale (2026 poster identity)

/// A small, coherent set of font styles for the redesign. Use these instead of
/// scattering ad-hoc `.font(.system(size:))` calls so the type scale stays
/// consistent. They set font + tracking only (not color), so callers keep
/// control of `foregroundStyle`.
extension View {
    /// 34pt heavy — top-level screen titles (Home, Explore, You).
    func gatherScreenTitle() -> some View { self.font(.system(size: 34, weight: .heavy)).kerning(-1) }
    /// 26pt heavy — poster / hero titles over imagery.
    func gatherPosterTitle() -> some View { self.font(.system(size: 26, weight: .heavy)).kerning(-0.5) }
    /// 20pt bold — prominent card titles.
    func gatherCardTitle() -> some View { self.font(.system(size: 20, weight: .bold)) }
    /// 17pt bold — section headers within a screen.
    func gatherSectionHeader() -> some View { self.font(.system(size: 17, weight: .bold)) }
    /// 15pt semibold — list-row titles.
    func gatherRowTitle() -> some View { self.font(.system(size: 15, weight: .semibold)) }
    /// 13pt medium — meta lines, subtitles, timestamps.
    func gatherMetaText() -> some View { self.font(.system(size: 13, weight: .medium)) }
    /// 11pt heavy, tracked — eyebrows and ALL-CAPS labels.
    func gatherEyebrow() -> some View { self.font(.system(size: 11, weight: .heavy)).tracking(0.5) }
}

// MARK: - Serif Display (the Gathr Editorial signature)

/// The signature voice of the app: Apple's New York serif at heavy weights for
/// event titles and screen headers — an editorial, invitation-like look that
/// no system-font app has. Body/meta text stays SF for readability; serif is
/// reserved for display moments so it stays special.
extension View {
    /// 40pt heavy serif — hero display (event detail hero, auth wordmark).
    func gatherSerifHero() -> some View { self.font(.system(size: 40, weight: .heavy, design: .serif)).kerning(-0.5) }
    /// 32pt heavy serif — screen titles (Home, Explore, Calendar, You).
    func gatherSerifScreenTitle() -> some View { self.font(.system(size: 32, weight: .heavy, design: .serif)).kerning(-0.5) }
    /// 26pt heavy serif — poster/card titles over imagery.
    func gatherSerifPosterTitle() -> some View { self.font(.system(size: 26, weight: .heavy, design: .serif)).kerning(-0.3) }
    /// 20pt bold serif — prominent inline titles (row/section display moments).
    func gatherSerifHeadline() -> some View { self.font(.system(size: 20, weight: .bold, design: .serif)) }
}

// MARK: - Accessibility Helpers

extension Font {
    /// Returns a font that respects Dynamic Type settings
    static func gatherScaled(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        Font.system(style).weight(weight)
    }
}
