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

    /// Responsive spacing that scales for iPad (regular width)
    static func responsive(_ base: CGFloat, for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        switch sizeClass {
        case .regular: return base * 1.25
        default: return base
        }
    }
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

    /// 20pt - Glass cards (friendlier, Partiful-style)
    static let card: CGFloat = 20

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

// MARK: - Animation Durations

enum AnimationDuration {
    /// 0.15s - Micro-interactions (press effects, highlights)
    static let fast: Double = 0.15

    /// 0.3s - Standard transitions (tabs, filters, sheets)
    static let standard: Double = 0.3

    /// 0.5s - Medium transitions (loading states, page changes)
    static let medium: Double = 0.5

    /// 0.8s - Slow animations (progress bars, entrance effects)
    static let slow: Double = 0.8
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

    /// Hero image height (expanded)
    static let heroImageHeight: CGFloat = 340

    /// Compact hero height
    static let heroImageHeightCompact: CGFloat = 200

    /// Content overlap above hero (Luma-style card overlap)
    static let heroContentOverlap: CGFloat = 30

    // MARK: Hero Image Heights

    /// 200pt - Standard hero card image
    static let heroHeight: CGFloat = 200

    /// 240pt - Featured card hero
    static let heroHeightFeatured: CGFloat = 240

    /// 300pt - Event detail hero
    static let heroHeightDetail: CGFloat = 300

    /// Adaptive hero heights based on size class
    static func heroHeight(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 280 : 200
    }

    static func heroHeightFeatured(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 320 : 240
    }

    static func heroHeightDetail(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 400 : 300
    }

    // MARK: Photo Displays

    /// 150pt - Photo display height
    static let photoHeight: CGFloat = 150

    // MARK: Scroll Bottom Insets

    /// 100pt - Bottom inset for floating buttons
    static let scrollBottomInset: CGFloat = 100

    /// 80pt - Compact bottom inset for floating buttons
    static let scrollBottomInsetCompact: CGFloat = 80

    // MARK: Avatar Sizes

    /// 32pt - Small avatar
    static let avatarSmall: CGFloat = 32

    /// 40pt - Medium avatar
    static let avatarMedium: CGFloat = 40

    /// 48pt - Large avatar
    static let avatarLarge: CGFloat = 48

    // MARK: Input Fields

    /// 52pt - Standard input field height
    static let inputHeight: CGFloat = 52

    /// 52pt - Standard button height
    static let buttonHeight: CGFloat = 52
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

// MARK: - GlassCard ViewModifier

struct GlassCardModifier: ViewModifier {
    var tint: Color = .clear
    var cornerRadius: CGFloat = CornerRadius.card
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.white.opacity(0.06), Color.white.opacity(0.02)]
                        : [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(tint.opacity(colorScheme == .dark ? 0.12 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color.white.opacity(0.15), Color.white.opacity(0.05)]
                                : [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 12, y: 4)
    }
}

// MARK: - Lightweight Glass Card (for scroll performance in lists)

struct GlassCardLiteModifier: ViewModifier {
    var cornerRadius: CGFloat = CornerRadius.card
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark
                ? Color.gatherSecondaryBackground.opacity(0.6)
                : Color.gatherSecondaryBackground.opacity(0.4)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.white.opacity(0.15),
                        lineWidth: 0.5
                    )
            )
    }
}

extension View {
    /// Apply glassmorphic card style
    func glassCard(tint: Color = .clear, cornerRadius: CGFloat = CornerRadius.card) -> some View {
        modifier(GlassCardModifier(tint: tint, cornerRadius: cornerRadius))
    }

    /// Lightweight glass card — no material blur, better scroll performance
    func glassCardLite(cornerRadius: CGFloat = CornerRadius.card) -> some View {
        modifier(GlassCardLiteModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Shimmer Loading Modifier

struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.4 : 0.8)
            .animation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    /// Apply shimmer loading effect (replaces ProgressView spinners)
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Loader View

struct SkeletonLoader: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = CornerRadius.sm

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gatherSecondaryBackground)
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Press Events

extension View {
    /// Add press/release event handlers for animations
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

// MARK: - Bouncy Appear Animation

extension View {
    func bouncyAppear(delay: Double = 0) -> some View {
        modifier(BouncyAppearModifier(delay: delay))
    }
}

struct BouncyAppearModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                guard !hasAppeared else {
                    isVisible = true  // instant show on navigation return
                    return
                }
                hasAppeared = true
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Card Press Effect (3D feel)

struct CardPressModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .rotation3DEffect(
                .degrees(isPressed ? 0.5 : 0),
                axis: (x: 1, y: 0, z: 0)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .pressEvents(
                onPress: { isPressed = true },
                onRelease: { isPressed = false }
            )
    }
}

extension View {
    /// Add 3D press effect to cards (scale + subtle rotation)
    func cardPress() -> some View {
        modifier(CardPressModifier())
    }
}

// MARK: - Card Press Button Style

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .rotation3DEffect(
                .degrees(configuration.isPressed ? 0.5 : 0),
                axis: (x: 1, y: 0, z: 0)
            )
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var startTime: Date?
    let colors: [Color] = [.warmCoral, .sunshineYellow, .mintGreen, .neonBlue, .neonPink, .accentPurpleFallback]

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = startTime.map { timeline.date.timeIntervalSince($0) } ?? 0
            Canvas { context, size in
                for particle in particles {
                    let pos = particlePosition(particle, elapsed: elapsed)
                    guard pos.opacity > 0 else { continue }
                    let rect = CGRect(
                        x: pos.x - particle.size / 2,
                        y: pos.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size * 0.6
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(particle.color.opacity(pos.opacity)))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            spawnParticles()
            startTime = Date()
        }
    }

    private func particlePosition(_ p: ConfettiParticle, elapsed: Double) -> (x: CGFloat, y: CGFloat, opacity: Double) {
        let frames = elapsed * 60
        let x = p.x + p.velocityX * frames
        let gravity: CGFloat = 0.15
        let y = p.y + p.velocityY * frames + 0.5 * gravity * frames * frames
        let opacity = y > 800 ? max(0, p.opacity - Double((y - 800) * 0.002)) : p.opacity
        return (x, y, opacity)
    }

    private func spawnParticles() {
        particles = (0..<60).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 50...350),
                y: CGFloat.random(in: -100...(-20)),
                size: CGFloat.random(in: 6...12),
                color: colors.randomElement() ?? .warmCoral,
                velocityX: CGFloat.random(in: -2...2),
                velocityY: CGFloat.random(in: 2...6),
                opacity: 1.0,
                rotation: Double.random(in: 0...360)
            )
        }
    }
}

struct ConfettiParticle {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var velocityX: CGFloat
    var velocityY: CGFloat
    var opacity: Double
    var rotation: Double
}

// MARK: - Animated Number Transition

extension View {
    /// Apply animated numeric text transition for counters
    func animatedNumber() -> some View {
        self.contentTransition(.numericText())
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: UUID())
    }
}

// MARK: - Overlapping Avatar Stack

struct AvatarStack: View {
    let names: [String]
    let maxDisplay: Int
    let size: CGFloat

    init(names: [String], maxDisplay: Int = 5, size: CGFloat = AvatarSize.sm) {
        self.names = names
        self.maxDisplay = maxDisplay
        self.size = size
    }

    var body: some View {
        HStack(spacing: -(size * 0.3)) {
            ForEach(Array(names.prefix(maxDisplay).enumerated()), id: \.offset) { index, name in
                Circle()
                    .fill(avatarColor(for: index))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.gatherBackground, lineWidth: 2)
                    )
                    .zIndex(Double(maxDisplay - index))
            }

            if names.count > maxDisplay {
                Circle()
                    .fill(Color.gatherSecondaryBackground)
                    .frame(width: size, height: size)
                    .overlay(
                        Text("+\(names.count - maxDisplay)")
                            .font(.system(size: size * 0.35, weight: .semibold))
                            .foregroundStyle(Color.gatherSecondaryText)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.gatherBackground, lineWidth: 2)
                    )
                    .zIndex(0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(names.count) \(names.count == 1 ? "person" : "people")")
    }

    private func avatarColor(for index: Int) -> Color {
        let colors: [Color] = [.accentPurpleFallback, .accentPinkFallback, .warmCoral, .mintGreen, .neonBlue]
        return colors[index % colors.count]
    }
}

// MARK: - "Name and X others" Text

struct AttendeePreviewText: View {
    let names: [String]
    let totalCount: Int

    var body: some View {
        if names.isEmpty {
            Text("Be the first to attend!")
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
        } else {
            let firstName = names.first?.components(separatedBy: " ").first ?? names.first ?? ""
            let remaining = totalCount - 1

            if remaining > 0 {
                Text("\(firstName) and \(remaining) other\(remaining == 1 ? "" : "s")")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            } else {
                Text("\(firstName) is going")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
        }
    }
}

// MARK: - Gradient Ring (Avatar border based on status)

struct GradientRing: ViewModifier {
    let color: Color
    let lineWidth: CGFloat

    init(color: Color, lineWidth: CGFloat = 2.5) {
        self.color = color
        self.lineWidth = lineWidth
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [color, color.opacity(0.5), color],
                            center: .center
                        ),
                        lineWidth: lineWidth
                    )
            )
    }
}

extension View {
    /// Add gradient ring around avatars (color matches RSVP status)
    func gradientRing(color: Color, lineWidth: CGFloat = 2.5) -> some View {
        modifier(GradientRing(color: color, lineWidth: lineWidth))
    }
}

// MARK: - MeshGradient Background (iOS 18+)

struct CategoryMeshBackground: View {
    let category: EventCategory
    @State private var animationPhase: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if #available(iOS 18.0, *) {
            meshGradientView
        } else {
            fallbackGradient
        }
    }

    @available(iOS 18.0, *)
    private var meshGradientView: some View {
        let colors = meshColors(for: category)
        return MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [Float(0.5 + sin(animationPhase) * 0.1), 0.5], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: colors
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                animationPhase = .pi * 2
            }
        }
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: [
                Color.forCategory(category),
                Color.forCategory(category).opacity(0.6),
                Color.accentPurpleFallback.opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Neutral fill that adapts to color scheme — avoids white patches in dark mode
    private var neutralFill: Color {
        colorScheme == .dark ? Color(white: 0.15) : .white.opacity(0.9)
    }

    private var neutralFillMid: Color {
        colorScheme == .dark ? Color(white: 0.12) : .white.opacity(0.8)
    }

    private var neutralFillLight: Color {
        colorScheme == .dark ? Color(white: 0.1) : .white.opacity(0.7)
    }

    @available(iOS 18.0, *)
    private func meshColors(for category: EventCategory) -> [Color] {
        switch category {
        case .wedding:
            return [
                .accentPinkFallback, .softLavender, neutralFill,
                .softLavender.opacity(0.8), .accentPinkFallback.opacity(0.6), .softLavender,
                neutralFill, .accentPinkFallback.opacity(0.4), .softLavender.opacity(0.7)
            ]
        case .party:
            return [
                .accentPurpleFallback, .accentPinkFallback, .neonPink.opacity(0.7),
                .accentPinkFallback.opacity(0.8), .accentPurpleFallback.opacity(0.6), .neonPink,
                .neonPink.opacity(0.5), .accentPurpleFallback.opacity(0.4), .accentPinkFallback
            ]
        case .concert:
            return [
                .warmCoral, .neonPink, .deepIndigo,
                .neonPink.opacity(0.8), .warmCoral.opacity(0.6), .deepIndigo.opacity(0.8),
                .deepIndigo, .neonPink.opacity(0.5), .warmCoral.opacity(0.7)
            ]
        case .conference:
            return [
                Color(red: 0.35, green: 0.55, blue: 1.0), .sunshineYellow.opacity(0.6), neutralFillMid,
                .sunshineYellow.opacity(0.4), Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.5), .sunshineYellow,
                neutralFillLight, Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.3), .sunshineYellow.opacity(0.5)
            ]
        case .meetup:
            return [
                .mintGreen, .neonBlue.opacity(0.4), neutralFill,
                .neonBlue.opacity(0.3), .mintGreen.opacity(0.6), neutralFillMid,
                neutralFill, .mintGreen.opacity(0.4), .neonBlue.opacity(0.3)
            ]
        case .office:
            return [
                Color(red: 0.35, green: 0.55, blue: 1.0), .softLavender.opacity(0.5), neutralFill,
                .softLavender.opacity(0.4), Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.3), neutralFillMid,
                neutralFill, .softLavender.opacity(0.3), Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.2)
            ]
        case .custom:
            return [
                .accentPurpleFallback.opacity(0.5), .gatherSecondaryBackground, neutralFillMid,
                .gatherSecondaryBackground, .accentPurpleFallback.opacity(0.3), .gatherSecondaryBackground,
                neutralFillLight, .gatherSecondaryBackground, .accentPurpleFallback.opacity(0.2)
            ]
        }
    }
}
