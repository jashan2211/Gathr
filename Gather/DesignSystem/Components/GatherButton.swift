import SwiftUI

// MARK: - Button Styles

enum GatherButtonStyle {
    case primary
    case secondary
    case ghost
    case destructive
}

enum GatherButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 44
        case .large: return 52
        }
    }

    var font: Font {
        switch self {
        case .small: return GatherFont.callout
        case .medium: return GatherFont.headline
        case .large: return GatherFont.headline
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return Spacing.md
        case .medium: return Spacing.lg
        case .large: return Spacing.xl
        }
    }
}

// MARK: - Gather Button

struct GatherButton: View {
    let title: String
    var icon: String? = nil
    var style: GatherButtonStyle = .primary
    var size: GatherButtonSize = .medium
    var isFullWidth: Bool = true
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            if !isLoading && !isDisabled {
                hapticFeedback()
                action()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(size.font)
                    }
                    Text(title)
                        .font(size.font)
                }
            }
            .foregroundStyle(foregroundColor)
            .frame(height: size.height)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, isFullWidth ? 0 : size.horizontalPadding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(overlay)
            .opacity(isDisabled ? 0.5 : 1.0)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .pressEvents {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = false
            }
        }
    }

    // MARK: - Styling

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            LinearGradient.gatherAccentGradient
        case .secondary:
            Color.gatherSecondaryBackground
        case .ghost:
            Color.clear
        case .destructive:
            Color.gatherDestructive
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary:
            return .gatherPrimaryText
        case .ghost:
            return .accentPurpleFallback
        }
    }

    @ViewBuilder
    private var overlay: some View {
        if style == .ghost {
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.accentPurpleFallback, lineWidth: 1.5)
        } else {
            EmptyView()
        }
    }

    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Icon Button

struct GatherIconButton: View {
    let icon: String
    var size: CGFloat = IconSize.lg
    var background: Color = .gatherSecondaryBackground
    var foreground: Color = .gatherPrimaryText
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.5))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(background)
                .clipShape(Circle())
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .pressEvents {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = false
            }
        }
    }
}

// MARK: - Previews

#Preview("Primary") {
    VStack(spacing: Spacing.md) {
        GatherButton(title: "Continue", style: .primary) {}
        GatherButton(title: "Continue", icon: "arrow.right", style: .primary) {}
        GatherButton(title: "Loading...", style: .primary, isLoading: true) {}
        GatherButton(title: "Disabled", style: .primary, isDisabled: true) {}
    }
    .padding()
}

#Preview("Secondary") {
    VStack(spacing: Spacing.md) {
        GatherButton(title: "Cancel", style: .secondary) {}
        GatherButton(title: "Edit", icon: "pencil", style: .secondary) {}
    }
    .padding()
}

#Preview("Ghost") {
    VStack(spacing: Spacing.md) {
        GatherButton(title: "Learn More", style: .ghost) {}
        GatherButton(title: "Sign Up", icon: "person.badge.plus", style: .ghost) {}
    }
    .padding()
}

#Preview("Destructive") {
    GatherButton(title: "Delete Event", icon: "trash", style: .destructive) {}
        .padding()
}

#Preview("Sizes") {
    VStack(spacing: Spacing.md) {
        GatherButton(title: "Small", size: .small, isFullWidth: false) {}
        GatherButton(title: "Medium", size: .medium, isFullWidth: false) {}
        GatherButton(title: "Large", size: .large, isFullWidth: false) {}
    }
    .padding()
}

#Preview("Icon Buttons") {
    HStack(spacing: Spacing.md) {
        GatherIconButton(icon: "heart") {}
        GatherIconButton(icon: "square.and.arrow.up") {}
        GatherIconButton(icon: "ellipsis") {}
    }
    .padding()
}
