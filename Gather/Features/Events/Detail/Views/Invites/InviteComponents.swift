import SwiftUI
import MessageUI
import CoreImage

// MARK: - Invite Quick Action Pill

struct InviteQuickActionPill: View {
    let title: String
    let count: Int
    let icon: String
    let isSelected: Bool
    /// When false the pill is a passive status indicator (e.g. "Custom" reflects
    /// the current hand-picked count) rather than a tappable action.
    var isInteractive: Bool = true
    let action: () -> Void

    var body: some View {
        Group {
            if isInteractive {
                Button(action: {
                    action()
                    HapticService.buttonTap()
                }) { pillContent }
            } else {
                pillContent
            }
        }
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }

    private var pillContent: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .fontWeight(.semibold)

            Text("\(count)")
                .font(GatherFont.headline)
                .fontWeight(.bold)

            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(
            isSelected
                ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                : AnyShapeStyle(Color.gatherSecondaryBackground)
        )
        .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Completion Stat Card

struct CompletionStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(Circle())

            Text(value)
                .font(GatherFont.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.gatherPrimaryText)

            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .surfaceCard(cornerRadius: CornerRadius.md)
    }
}

// MARK: - Guest Chip

struct GuestChip: View {
    let guest: Guest
    let isSelected: Bool
    let onTap: () -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                // Mini avatar
                Circle()
                    .fill(
                        isSelected
                            ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                            : AnyShapeStyle(Color.gatherSecondaryText.opacity(0.3))
                    )
                    .frame(width: 18, height: 18)
                    .overlay {
                        Text(String(guest.name.prefix(1)).uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(isSelected ? .white : Color.gatherSecondaryText)
                    }

                VStack(alignment: .leading, spacing: 0) {
                    Text(guest.name)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    // Invite delivery metadata — "Sent · 2 hr. ago"
                    if let sentAt = guest.inviteSentAt {
                        Text("Sent · \(Self.relativeFormatter.localizedString(for: sentAt, relativeTo: Date()))")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.rsvpYesFallback)
                            .lineLimit(1)
                    }
                }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentPurpleFallback.opacity(0.15) : Color.gatherTertiaryBackground)
            .foregroundStyle(isSelected ? Color.accentPurpleFallback : Color.gatherPrimaryText)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.accentPurpleFallback.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var label = guest.name
        label += isSelected ? ", selected" : ", not selected"
        if let sentAt = guest.inviteSentAt {
            label += ", invite sent \(Self.relativeFormatter.localizedString(for: sentAt, relativeTo: Date()))"
        }
        return label
    }
}

// MARK: - Function Chip

struct FunctionChip: View {
    let function: EventFunction
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentPurpleFallback : Color.gatherSecondaryText.opacity(0.2))
                        .frame(width: 24, height: 24)

                    Image(systemName: isSelected ? "checkmark" : "calendar")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isSelected ? .white : Color.gatherSecondaryText)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(function.name)
                        .font(GatherFont.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text(function.formattedDateRange)
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()
            }
            .padding(Spacing.sm)
            .background(isSelected ? Color.accentPurpleFallback.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        }
    }
}

// MARK: - Channel Button

struct ChannelButton: View {
    let channel: InviteChannel
    let isSelected: Bool
    let availableCount: Int
    let totalCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color(channel.color).opacity(0.15))
                            .frame(width: 52, height: 52)
                    }

                    Image(systemName: channel.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? .white : Color(channel.color))
                        .frame(width: 44, height: 44)
                        .background(
                            isSelected
                                ? AnyShapeStyle(LinearGradient(colors: [Color(channel.color), Color(channel.color).opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color(channel.color).opacity(0.1))
                        )
                        .clipShape(Circle())
                }

                Text(channel.shortName)
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundStyle(isSelected ? Color.gatherPrimaryText : Color.gatherSecondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Channel Extensions

extension InviteChannel {
    var shortName: String {
        switch self {
        case .whatsapp: return "WhatsApp"
        case .sms: return "SMS"
        case .email: return "Email"
        case .copied: return "Copy"
        case .inAppLink: return "Link"
        }
    }
}

// MARK: - In-App Message Compose (MessageUI)

/// SwiftUI wrapper around `MFMessageComposeViewController` so SMS invites are
/// composed in-app instead of bouncing the host out to the Messages app.
/// The parent owns presentation — on finish it swaps in the next guest's
/// compose (via `.id`) rather than dismissing.
struct InviteMessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onFinish: (MessageComposeResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (MessageComposeResult) -> Void

        init(onFinish: @escaping (MessageComposeResult) -> Void) {
            self.onFinish = onFinish
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            onFinish(result)
        }
    }
}

// MARK: - In-App Mail Compose (MessageUI)

/// SwiftUI wrapper around `MFMailComposeViewController`. Used both for the
/// one-tap BCC email blast and the personalized one-by-one email flow.
struct InviteMailComposeView: UIViewControllerRepresentable {
    let toRecipients: [String]
    let bccRecipients: [String]
    let subject: String
    let body: String
    let onFinish: (MFMailComposeResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.setToRecipients(toRecipients)
        controller.setBccRecipients(bccRecipients)
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        controller.mailComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult) -> Void

        init(onFinish: @escaping (MFMailComposeResult) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish(result)
        }
    }
}

// MARK: - Invite QR Code

/// QR code for the event share link, rendered with CoreImage's
/// `CIQRCodeGenerator`. Images are memoized — body re-evaluations of the
/// parent sheet shouldn't re-run the CIFilter pipeline.
struct InviteQRCodeView: View {
    let urlString: String

    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        if let image = Self.qrImage(for: urlString) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.gatherSecondaryText.opacity(0.4))
        }
    }

    static func qrImage(for string: String) -> UIImage? {
        if let cached = cache.object(forKey: string as NSString) {
            return cached
        }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }

        // Scale up — the raw output is tiny and would blur when resized.
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: string as NSString)
        return image
    }
}

// MARK: - Delivery Plan Row

/// One line of the smart-routing plan, e.g. "8 via Messages".
struct InvitePlanRow: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            Text("\(count)")
                .font(GatherFont.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.gatherPrimaryText)
                .monospacedDigit()

            Text(label)
                .font(GatherFont.callout)
                .foregroundStyle(Color.gatherSecondaryText)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) \(label)")
    }
}
