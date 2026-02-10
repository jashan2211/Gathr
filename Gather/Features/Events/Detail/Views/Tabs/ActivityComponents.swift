import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Activity Post Card

struct ActivityPostCard: View {
    let post: ActivityPost
    let event: Event
    let replies: [ActivityPost]
    let onReply: () -> Void
    let onLike: () -> Void
    let onPin: (() -> Void)?
    let onDelete: (() -> Void)?
    let onVote: (UUID) -> Void

    @EnvironmentObject var authManager: AuthManager
    @State private var showReplies = false

    private var isLiked: Bool {
        guard let userId = authManager.currentUser?.id else { return false }
        return post.isLikedBy(userId: userId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pinned indicator
            if post.isPinned {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                    Text("Pinned")
                        .font(GatherFont.caption)
                }
                .foregroundStyle(Color.accentPurpleFallback)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
            }

            // Main content
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Header
                HStack(spacing: Spacing.sm) {
                    // Avatar
                    Circle()
                        .fill(post.isHostPost
                              ? LinearGradient.gatherAccentGradient
                              : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(post.authorName.prefix(1)))
                                .font(GatherFont.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: Spacing.xs) {
                            Text(post.authorName)
                                .font(GatherFont.callout)
                                .fontWeight(.semibold)

                            if post.isHostPost {
                                Text("Host")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentPurpleFallback)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(post.timeAgo)
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherTertiaryText)
                    }

                    Spacer()

                    // Post type badge
                    postTypeBadge

                    // Overflow menu
                    if onPin != nil || onDelete != nil {
                        Menu {
                            if let onPin = onPin {
                                Button {
                                    onPin()
                                } label: {
                                    Label(post.isPinned ? "Unpin" : "Pin", systemImage: post.isPinned ? "pin.slash" : "pin")
                                }
                            }
                            if let onDelete = onDelete {
                                Button(role: .destructive) {
                                    onDelete()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundStyle(Color.gatherSecondaryText)
                                .frame(width: 28, height: 28)
                        }
                    }
                }

                // Content
                Text(post.text)
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherPrimaryText)

                // Poll options
                if post.postType == .poll, let options = post.pollOptions {
                    pollView(options: options)
                }

                // Photo
                if post.postType == .photo, let imageData = post.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }

                // Actions bar
                HStack(spacing: Spacing.lg) {
                    // Like
                    Button(action: onLike) {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundStyle(isLiked ? .red : Color.gatherSecondaryText)
                            if post.likes > 0 {
                                Text("\(post.likes)")
                                    .font(GatherFont.caption)
                                    .foregroundStyle(Color.gatherSecondaryText)
                            }
                        }
                        .font(.subheadline)
                    }

                    // Reply
                    Button(action: onReply) {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "bubble.left")
                            if !replies.isEmpty {
                                Text("\(replies.count)")
                                    .font(GatherFont.caption)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.gatherSecondaryText)
                    }

                    Spacer()
                }

                // Replies
                if !replies.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showReplies.toggle()
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                            Text(showReplies ? "Hide replies" : "\(replies.count) \(replies.count == 1 ? "reply" : "replies")")
                                .font(GatherFont.caption)
                        }
                        .foregroundStyle(Color.accentPurpleFallback)
                    }

                    if showReplies {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            ForEach(replies) { reply in
                                replyCard(reply)
                            }
                        }
                        .padding(.leading, Spacing.lg)
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(Color.gatherSecondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    // MARK: - Post Type Badge

    private var postTypeBadge: some View {
        Group {
            switch post.postType {
            case .announcement:
                badgeLabel("Announcement", color: .orange)
            case .question:
                badgeLabel("Q&A", color: .blue)
            case .poll:
                badgeLabel("Poll", color: .accentPurpleFallback)
            default:
                EmptyView()
            }
        }
    }

    private func badgeLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Poll View

    private func pollView(options: [PollOption]) -> some View {
        let totalVotes = options.reduce(0) { $0 + $1.voteCount }
        let userId = authManager.currentUser?.id

        return VStack(spacing: Spacing.xs) {
            ForEach(options) { option in
                let hasVoted = userId.map { option.voterIds.contains($0) } ?? false
                let percentage = totalVotes > 0 ? Double(option.voteCount) / Double(totalVotes) : 0

                Button {
                    onVote(option.id)
                } label: {
                    HStack {
                        Text(option.text)
                            .font(GatherFont.callout)
                            .foregroundStyle(hasVoted ? Color.accentPurpleFallback : Color.gatherPrimaryText)

                        Spacer()

                        if totalVotes > 0 {
                            Text("\(Int(percentage * 100))%")
                                .font(GatherFont.caption)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .fill(hasVoted ? Color.accentPurpleFallback.opacity(0.15) : Color.gatherSecondaryBackground)
                                .frame(width: geo.size.width * percentage)
                        }
                    )
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(hasVoted ? Color.accentPurpleFallback.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            if totalVotes > 0 {
                Text("\(totalVotes) \(totalVotes == 1 ? "vote" : "votes")")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherTertiaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Reply Card

    private func replyCard(_ reply: ActivityPost) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Circle()
                .fill(reply.isHostPost
                      ? LinearGradient.gatherAccentGradient
                      : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(String(reply.authorName.prefix(1)))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(reply.authorName)
                        .font(GatherFont.caption)
                        .fontWeight(.semibold)

                    if reply.isHostPost {
                        Text("Host")
                            .font(.system(size: 9))
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.xxs)
                            .padding(.vertical, 1)
                            .background(Color.accentPurpleFallback)
                            .clipShape(Capsule())
                    }

                    Text(reply.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(Color.gatherTertiaryText)
                }

                Text(reply.text)
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherPrimaryText)
            }
        }
    }
}

// MARK: - Compose Post Sheet

struct ComposePostSheet: View {
    let event: Event
    @State var postType: ActivityPostType
    let parentPost: ActivityPost?
    let onPost: (ActivityPost) -> Void

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var pollOptionTexts: [String] = ["", ""]
    @State private var allowMultipleVotes = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?

    private var isHost: Bool {
        event.hostId == authManager.currentUser?.id
    }

    private var isValid: Bool {
        if postType == .poll {
            return !text.isEmpty && pollOptionTexts.filter { !$0.isEmpty }.count >= 2
        }
        return !text.isEmpty || selectedImageData != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    // Post type selector (host only, not for replies)
                    if isHost && parentPost == nil {
                        postTypeSelector
                    }

                    // Replying to indicator
                    if let parent = parentPost {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "arrowshape.turn.up.left")
                                .font(.caption)
                            Text("Replying to \(parent.authorName)")
                                .font(GatherFont.caption)
                        }
                        .foregroundStyle(Color.accentPurpleFallback)
                        .padding(.horizontal, Spacing.md)
                    }

                    // Text input
                    TextField(placeholderText, text: $text, axis: .vertical)
                        .font(GatherFont.body)
                        .lineLimit(3...10)
                        .padding(Spacing.md)
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        .padding(.horizontal, Spacing.md)

                    // Poll options
                    if postType == .poll && parentPost == nil {
                        pollOptionsSection
                    }

                    // Photo picker
                    if postType == .photo && parentPost == nil {
                        photoPickerSection
                    }
                }
                .padding(.vertical, Spacing.md)
            }
            .navigationTitle(parentPost != nil ? "Reply" : "New \(postType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        createPost()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    private var placeholderText: String {
        if parentPost != nil { return "Write your reply..." }
        switch postType {
        case .announcement: return "Share an important update..."
        case .question: return "Ask a question about this event..."
        case .poll: return "What would you like to ask?"
        case .photo: return "Add a caption..."
        default: return "What's on your mind?"
        }
    }

    // MARK: - Post Type Selector

    private var postTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                postTypeChip(.announcement)
                postTypeChip(.poll)
                postTypeChip(.photo)
                postTypeChip(.question)
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func postTypeChip(_ type: ActivityPostType) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                postType = type
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: type.icon)
                    .font(.caption)
                Text(type.displayName)
                    .font(GatherFont.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(postType == type ? .white : Color.gatherPrimaryText)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(postType == type ? Color.accentPurpleFallback : Color.gatherSecondaryBackground)
            .clipShape(Capsule())
        }
    }

    // MARK: - Poll Options

    private var pollOptionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Poll Options")
                .font(GatherFont.callout)
                .fontWeight(.medium)
                .padding(.horizontal, Spacing.md)

            VStack(spacing: Spacing.xs) {
                ForEach(pollOptionTexts.indices, id: \.self) { index in
                    HStack {
                        TextField("Option \(index + 1)", text: $pollOptionTexts[index])
                            .font(GatherFont.body)
                            .padding(Spacing.sm)
                            .background(Color.gatherSecondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                        if pollOptionTexts.count > 2 {
                            Button {
                                pollOptionTexts.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.gatherSecondaryText)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)

            if pollOptionTexts.count < 6 {
                Button {
                    pollOptionTexts.append("")
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus.circle")
                        Text("Add option")
                    }
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.accentPurpleFallback)
                }
                .padding(.horizontal, Spacing.md)
            }

            Toggle("Allow multiple votes", isOn: $allowMultipleVotes)
                .font(GatherFont.callout)
                .tint(Color.accentPurpleFallback)
                .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Photo Picker

    private var photoPickerSection: some View {
        VStack(spacing: Spacing.sm) {
            if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .padding(.horizontal, Spacing.md)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            selectedImageData = nil
                            selectedPhoto = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        .padding(Spacing.lg)
                    }
            } else {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "photo.badge.plus")
                            .font(.largeTitle)
                            .foregroundStyle(Color.accentPurpleFallback)
                        Text("Select a photo")
                            .font(GatherFont.callout)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.photoHeight)
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .padding(.horizontal, Spacing.md)
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
    }

    // MARK: - Create Post

    private func createPost() {
        let post = ActivityPost(
            text: text,
            postType: parentPost != nil ? (postType == .answer ? .answer : .update) : postType,
            isPinned: false,
            pollOptions: postType == .poll && parentPost == nil
                ? pollOptionTexts.filter { !$0.isEmpty }.map { PollOption(text: $0) }
                : nil,
            allowsMultipleVotes: allowMultipleVotes,
            imageData: postType == .photo ? selectedImageData : nil,
            parentPostId: parentPost?.id,
            authorId: authManager.currentUser?.id,
            authorName: authManager.currentUser?.name ?? "Guest",
            isHostPost: isHost,
            eventId: event.id
        )
        onPost(post)

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
