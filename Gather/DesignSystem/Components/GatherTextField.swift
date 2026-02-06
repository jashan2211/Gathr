import SwiftUI

// MARK: - Gather Text Field

struct GatherTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure: Bool = false
    var errorMessage: String? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Label
            Text(label)
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)

            // Input field
            HStack(spacing: Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(isFocused ? Color.accentPurpleFallback : Color.gatherSecondaryText)
                }

                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textContentType(textContentType)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                        .textInputAutocapitalization(autocapitalization)
                }
            }
            .font(GatherFont.body)
            .padding()
            .background(Color.gatherSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 0)
            )
            .focused($isFocused)

            // Error message
            if let errorMessage = errorMessage {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text(errorMessage)
                        .font(GatherFont.caption)
                }
                .foregroundStyle(Color.gatherDestructive)
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return .gatherDestructive
        } else if isFocused {
            return .accentPurpleFallback
        } else {
            return .clear
        }
    }
}

// MARK: - Text Area

struct GatherTextArea: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var minLines: Int = 3
    var maxLines: Int = 6
    var errorMessage: String? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Label
            Text(label)
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)

            // Text editor
            TextField(placeholder, text: $text, axis: .vertical)
                .font(GatherFont.body)
                .lineLimit(minLines...maxLines)
                .padding()
                .background(Color.gatherSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(borderColor, lineWidth: isFocused ? 2 : 0)
                )
                .focused($isFocused)

            // Error message
            if let errorMessage = errorMessage {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text(errorMessage)
                        .font(GatherFont.caption)
                }
                .foregroundStyle(Color.gatherDestructive)
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return .gatherDestructive
        } else if isFocused {
            return .accentPurpleFallback
        } else {
            return .clear
        }
    }
}

// MARK: - Previews

#Preview("Text Field") {
    VStack(spacing: Spacing.lg) {
        GatherTextField(
            label: "Email",
            placeholder: "Enter your email",
            text: .constant(""),
            icon: "envelope"
        )

        GatherTextField(
            label: "Email",
            placeholder: "Enter your email",
            text: .constant("test@example.com"),
            icon: "envelope"
        )

        GatherTextField(
            label: "Email",
            placeholder: "Enter your email",
            text: .constant("invalid"),
            icon: "envelope",
            errorMessage: "Please enter a valid email"
        )
    }
    .padding()
}

#Preview("Text Area") {
    VStack(spacing: Spacing.lg) {
        GatherTextArea(
            label: "Description",
            placeholder: "What's this event about?",
            text: .constant("")
        )

        GatherTextArea(
            label: "Description",
            placeholder: "What's this event about?",
            text: .constant("Join us for an amazing evening of fun and festivities! There will be food, drinks, and great company.")
        )
    }
    .padding()
}
