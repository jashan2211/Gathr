import SwiftUI

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

    // MARK: - Actions

    private func shareViaMessages() {
        // Open Messages with prefilled content
        let text = "You're invited to \(event.title)! \(shareURL)"
        if let url = URL(string: "sms:&body=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }

    private func shareViaEmail() {
        let subject = "You're invited: \(event.title)"
        let body = """
        Hi!

        You're invited to \(event.title).

        RSVP here: \(shareURL)

        Hope to see you there!
        """

        if let url = URL(string: "mailto:?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }

    private func shareViaSystem() {
        let text = "You're invited to \(event.title)! RSVP here: \(shareURL)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func copyLink() {
        UIPasteboard.general.string = shareURL
        withAnimation {
            linkCopied = true
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

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
