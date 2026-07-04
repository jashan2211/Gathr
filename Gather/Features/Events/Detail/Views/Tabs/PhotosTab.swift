import SwiftUI
import SwiftData

// MARK: - Photos Tab (link-based)

/// Attendees share a LINK to a photo album (Google Photos, iCloud Shared Album,
/// Dropbox, etc.) rather than uploading images. This keeps the app free of image
/// hosting entirely and avoids the heavy on-device photo-import path — guests
/// just tap through to the album in their browser.
struct PhotosTab: View {
    let event: Event
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var photos: [MediaItem]

    @State private var showAddLink = false

    init(event: Event) {
        self.event = event
        let eventId = event.id
        _photos = Query(
            filter: #Predicate<MediaItem> { $0.eventId == eventId && $0.url != nil },
            sort: \MediaItem.createdAt,
            order: .reverse
        )
    }

    private var myId: UUID? { authManager.currentUser?.id }
    private var isHost: Bool { event.hostId == myId }
    private func canDelete(_ item: MediaItem) -> Bool { isHost || item.uploaderId == myId }

    var body: some View {
        // Content-only: EventDetailView owns the page scroll.
        Group {
            VStack(spacing: Spacing.md) {
                addLinkBar

                if photos.isEmpty {
                    emptyState
                } else {
                    header
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(photos) { item in
                            linkCard(item)
                        }
                    }
                    .horizontalPadding()
                }
            }
            .padding(.vertical, Spacing.sm)
        }
        .sheet(isPresented: $showAddLink) {
            AddPhotoLinkSheet(event: event)
                .presentationDetents([.height(320), .medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Add-link bar

    private var addLinkBar: some View {
        Button {
            showAddLink = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "link.badge.plus")
                    .font(.title3)
                    .foregroundStyle(Color.accentPurpleFallback)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a photo link")
                        .font(GatherFont.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text("Share a Google Photos, iCloud, or Dropbox album")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(Spacing.md)
            .surfaceCard(cornerRadius: CornerRadius.lg)
        }
        .horizontalPadding()
    }

    private var header: some View {
        HStack {
            Text("Photo Albums")
                .gatherSectionHeader()
                .foregroundStyle(Color.gatherPrimaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text("\(photos.count)")
                .font(GatherFont.caption)
                .fontWeight(.bold)
                .foregroundStyle(Color.gatherSecondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.gatherElevated)
                .clipShape(Capsule())
        }
        .horizontalPadding()
    }

    // MARK: - Link card

    private func linkCard(_ item: MediaItem) -> some View {
        Button {
            if let url = item.url { openURL(url) }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "photo.stack")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(LinearGradient.gatherAccentGradient,
                                in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.caption?.isEmpty == false ? item.caption! : (item.url?.host ?? "Photo album"))
                        .gatherRowTitle()
                        .foregroundStyle(Color.gatherPrimaryText)
                        .lineLimit(1)
                    Text(item.url?.host ?? item.url?.absoluteString ?? "")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.accentPurpleFallback)
                        .lineLimit(1)
                    Text("Shared by \(item.uploaderName.isEmpty ? "a guest" : item.uploaderName)")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .lineLimit(1)
                }

                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.body)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(Spacing.md)
            .surfaceCard(cornerRadius: CornerRadius.md)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let url = item.url {
                Button {
                    UIPasteboard.general.string = url.absoluteString
                } label: {
                    Label("Copy Link", systemImage: "doc.on.doc")
                }
            }
            if canDelete(item) {
                Button(role: .destructive) {
                    deleteLink(item)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        .accessibilityLabel("\(item.caption?.isEmpty == false ? item.caption! : "Photo album") shared by \(item.uploaderName.isEmpty ? "a guest" : item.uploaderName)")
        .accessibilityHint("Double tap to open the album")
    }

    private var emptyState: some View {
        GatherEmptyState(
            icon: "photo.on.rectangle.angled",
            title: "No photo albums yet",
            message: "Share a link to your Google Photos, iCloud, or Dropbox album so everyone can see the pics.",
            accent: Color.forCategory(event.category)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    private func deleteLink(_ item: MediaItem) {
        modelContext.delete(item)
        modelContext.safeSave()
        HapticService.success()
    }
}

// MARK: - Add Photo Link Sheet

struct AddPhotoLinkSheet: View {
    let event: Event
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var linkText = ""
    @State private var caption = ""
    @State private var error: String?

    /// Parses the pasted text into a secure https URL, adding the scheme if the
    /// user pasted a bare host.
    private var normalizedURL: URL? {
        var s = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") {
            s = "https://" + s
        }
        guard let url = URL(string: s),
              url.scheme?.lowercased() == "https",
              url.host != nil else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Paste a link to a shared photo album — Google Photos, iCloud Shared Album, Dropbox, or any web link. Nothing is uploaded; guests just tap through to view.")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)

                    fieldLabel("Photo link")
                    TextField("https://photos.app.goo.gl/…", text: $linkText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .padding(Spacing.md)
                        .background(Color.gatherElevated, in: RoundedRectangle(cornerRadius: CornerRadius.md))

                    fieldLabel("Title (optional)")
                    TextField("e.g. Ceremony photos", text: $caption)
                        .padding(Spacing.md)
                        .background(Color.gatherElevated, in: RoundedRectangle(cornerRadius: CornerRadius.md))

                    if let error {
                        Text(error)
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.rsvpNoFallback)
                    }
                }
                .horizontalPadding()
                .padding(.top, Spacing.md)
            }
            .background(Color.gatherCanvas.ignoresSafeArea())
            .navigationTitle("Add Photo Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .fontWeight(.semibold)
                        .disabled(linkText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .gatherEyebrow()
            .foregroundStyle(Color.gatherSecondaryText)
    }

    private func add() {
        guard let url = normalizedURL else {
            error = "That doesn't look like a valid link — it should start with https://"
            return
        }
        let trimmedCaption = caption.trimmingCharacters(in: .whitespaces)
        let item = MediaItem(
            type: .image,
            url: url,
            caption: trimmedCaption.isEmpty ? nil : trimmedCaption,
            eventId: event.id,
            uploaderId: authManager.currentUser?.id,
            uploaderName: authManager.currentUser?.name ?? "Guest"
        )
        modelContext.insert(item)
        modelContext.safeSave()
        HapticService.success()
        dismiss()
    }
}
