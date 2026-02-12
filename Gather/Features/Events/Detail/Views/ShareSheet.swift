import SwiftUI

// MARK: - Deep Link Limitation
// NOTE: The `gather://` custom URL scheme only works for users who have the Gather app installed.
// Recipients without the app will see a non-functional link. The share text includes event details
// (title, date, location) so it remains useful even without the app.
//
// TODO: Implement Universal Links (Apple App Site Association) with a web fallback page
// hosted at e.g. https://gather.app/event/<id>. This requires:
//   1. A web server hosting an `apple-app-site-association` file
//   2. Associated Domains entitlement configured in Xcode
//   3. A fallback web page that displays event info for non-app users
// Once Universal Links are in place, replace the `gather://` scheme with `https://gather.app/event/`
// URLs so links work for everyone.

struct ShareSheet: View {
    let event: Event
    @Environment(\.dismiss) var dismiss
    @State private var linkCopied = false
    @State private var shareURL: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                // Event preview
                eventPreview

                Divider()

                // Share options
                VStack(spacing: Spacing.md) {
                    Text("Share via")
                        .font(GatherFont.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: Spacing.xl) {
                        ShareOptionButton(
                            icon: "message.fill",
                            label: "Message",
                            color: .green
                        ) {
                            shareViaMessages()
                        }

                        ShareOptionButton(
                            icon: "envelope.fill",
                            label: "Email",
                            color: .blue
                        ) {
                            shareViaEmail()
                        }

                        ShareOptionButton(
                            icon: "square.and.arrow.up",
                            label: "More",
                            color: .gray
                        ) {
                            shareViaSystem()
                        }
                    }
                }

                Divider()

                // Copy link
                VStack(spacing: Spacing.sm) {
                    Text("Or copy link")
                        .font(GatherFont.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Text(shareURL)
                            .font(GatherFont.callout)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .lineLimit(1)

                        Spacer()

                        Button {
                            copyLink()
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: linkCopied ? "checkmark" : "doc.on.doc")
                                Text(linkCopied ? "Copied!" : "Copy")
                            }
                            .font(GatherFont.callout)
                            .foregroundStyle(linkCopied ? Color.gatherSuccess : Color.accentPurpleFallback)
                        }
                    }
                    .padding()
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }

                Spacer()
            }
            .horizontalPadding()
            .padding(.top, Spacing.lg)
            .navigationTitle("Share Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            shareURL = "gather://event/\(event.id.uuidString)"
        }
    }

    // MARK: - Event Preview

    private var eventPreview: some View {
        HStack(spacing: Spacing.md) {
            // Thumbnail
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(LinearGradient.gatherAccentGradient)
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(event.title)
                    .font(GatherFont.headline)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            Spacer()
        }
    }

    private var formattedDate: String {
        GatherDateFormatter.fullEventDate.string(from: event.startDate)
    }

    // MARK: - Share Text Builder

    /// Builds a descriptive share message that is useful even for recipients who don't have the app.
    /// Includes event title, date, and location so the invite is self-contained.
    private var shareText: String {
        var lines: [String] = []
        lines.append("You're invited to \(event.title)!")
        lines.append("")
        lines.append("Date: \(formattedDate)")
        if let location = event.location {
            if let shortLoc = location.shortLocation {
                lines.append("Location: \(location.name) (\(shortLoc))")
            } else {
                lines.append("Location: \(location.name)")
            }
        }
        if let desc = event.eventDescription, !desc.isEmpty {
            lines.append("")
            lines.append(desc)
        }
        lines.append("")
        lines.append("Open in Gather: \(shareURL)")
        return lines.joined(separator: "\n")
    }

    // MARK: - Actions

    private func shareViaMessages() {
        let text = shareText
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "sms:&body=\(encoded)") else {
            // Fallback to system share
            shareViaSystem()
            return
        }
        UIApplication.shared.open(url) { success in
            if !success { shareViaSystem() }
        }
    }

    private func shareViaEmail() {
        let subject = "You're invited: \(event.title)"
        let body = shareText

        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)") else {
            shareViaSystem()
            return
        }
        UIApplication.shared.open(url) { success in
            if !success { shareViaSystem() }
        }
    }

    private func shareViaSystem() {
        let items: [Any] = [shareText]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        // Find the topmost presented VC so we don't conflict with the SwiftUI sheet
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        // iPad requires popover source or UIActivityViewController crashes
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        topVC.present(activityVC, animated: true)
    }

    private func copyLink() {
        UIPasteboard.general.string = shareURL
        withAnimation {
            linkCopied = true
        }

        // Haptic feedback
        HapticService.buttonTap()

        // Reset after delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                linkCopied = false
            }
        }
    }
}

// MARK: - Share Option Button

struct ShareOptionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }

                Text(label)
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
        }
    }
}

// MARK: - Share Activity Sheet (UIKit wrapper)

struct ShareActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ShareSheet(
        event: Event(
            title: "Birthday Party",
            startDate: Date().addingTimeInterval(86400 * 3)
        )
    )
}
