import SwiftUI
import SwiftData

// MARK: - Activity Tab

struct ActivityTab: View {
    let event: Event
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Query private var eventPosts: [ActivityPost]

    @State private var showComposer = false
    @State private var composerType: ActivityPostType = .question
    @State private var replyingTo: ActivityPost?

    init(event: Event) {
        self.event = event
        let eventId = event.id
        _eventPosts = Query(
            filter: #Predicate<ActivityPost> { $0.eventId == eventId },
            sort: \ActivityPost.createdAt,
            order: .reverse
        )
    }

    private var posts: [ActivityPost] {
        eventPosts
            .filter { $0.parentPostId == nil }
            .sorted { first, second in
                // Pinned first, then by date
                if first.isPinned != second.isPinned { return first.isPinned }
                return first.createdAt > second.createdAt
            }
    }

    private var isHost: Bool {
        event.hostId == authManager.currentUser?.id
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                // Composer bar
                composerBar

                if posts.isEmpty {
                    emptyState
                } else {
                    ForEach(posts) { post in
                        ActivityPostCard(
                            post: post,
                            event: event,
                            replies: repliesFor(post),
                            onReply: {
                                replyingTo = post
                                composerType = post.postType == .question ? .answer : .update
                                showComposer = true
                            },
                            onLike: { toggleLike(post) },
                            onPin: isHost ? { togglePin(post) } : nil,
                            onDelete: canDelete(post) ? { deletePost(post) } : nil,
                            onVote: { optionId in vote(on: post, optionId: optionId) }
                        )
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .sheet(isPresented: $showComposer) {
            ComposePostSheet(
                event: event,
                postType: composerType,
                parentPost: replyingTo,
                onPost: { post in
                    modelContext.insert(post)
                    modelContext.safeSave()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Composer Bar

    private var composerBar: some View {
        HStack(spacing: Spacing.sm) {
            // Avatar
            Circle()
                .fill(LinearGradient.gatherAccentGradient)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(authManager.currentUser?.name.prefix(1) ?? "?"))
                        .font(GatherFont.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                )

            // Composer button
            Button {
                composerType = isHost ? .announcement : .question
                replyingTo = nil
                showComposer = true
            } label: {
                Text(isHost ? "Share an update..." : "Ask a question...")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(Capsule())
            }

            // Quick actions
            if isHost {
                Menu {
                    Button {
                        composerType = .announcement
                        replyingTo = nil
                        showComposer = true
                    } label: {
                        Label("Announcement", systemImage: "megaphone.fill")
                    }
                    Button {
                        composerType = .poll
                        replyingTo = nil
                        showComposer = true
                    } label: {
                        Label("Poll", systemImage: "chart.bar.fill")
                    }
                    Button {
                        composerType = .photo
                        replyingTo = nil
                        showComposer = true
                    } label: {
                        Label("Photo", systemImage: "photo.fill")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentPurpleFallback)
                }
                .accessibilityLabel("New post")
            }
        }
        .padding(Spacing.md)
        .background(Color.gatherSecondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(Color.gatherSecondaryText.opacity(0.5))

            Text("No activity yet")
                .font(GatherFont.headline)
                .foregroundStyle(Color.gatherSecondaryText)

            Text(isHost
                 ? "Post an announcement or create a poll to engage your guests"
                 : "Be the first to ask a question about this event")
                .font(GatherFont.callout)
                .foregroundStyle(Color.gatherTertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Helpers

    private func repliesFor(_ post: ActivityPost) -> [ActivityPost] {
        eventPosts
            .filter { $0.parentPostId == post.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func toggleLike(_ post: ActivityPost) {
        guard let userId = authManager.currentUser?.id else { return }
        if post.likedByUserIds.contains(userId) {
            post.likedByUserIds.removeAll { $0 == userId }
            post.likes = max(0, post.likes - 1)
        } else {
            post.likedByUserIds.append(userId)
            post.likes += 1
        }
        HapticService.buttonTap()
    }

    private func togglePin(_ post: ActivityPost) {
        post.isPinned.toggle()
    }

    private func canDelete(_ post: ActivityPost) -> Bool {
        isHost || post.authorId == authManager.currentUser?.id
    }

    private func deletePost(_ post: ActivityPost) {
        // Delete replies first
        let replies = repliesFor(post)
        for reply in replies {
            modelContext.delete(reply)
        }
        modelContext.delete(post)
        modelContext.safeSave()
    }

    private func vote(on post: ActivityPost, optionId: UUID) {
        guard let userId = authManager.currentUser?.id,
              var options = post.pollOptions else { return }

        // Check if already voted on this option
        if let idx = options.firstIndex(where: { $0.id == optionId }) {
            if options[idx].voterIds.contains(userId) {
                // Remove vote
                options[idx].voterIds.removeAll { $0 == userId }
                options[idx].voteCount = max(0, options[idx].voteCount - 1)
            } else {
                // If single vote, remove from other options first
                if !post.allowsMultipleVotes {
                    for i in options.indices {
                        options[i].voterIds.removeAll { $0 == userId }
                        options[i].voteCount = options[i].voterIds.count
                    }
                }
                // Add vote
                options[idx].voterIds.append(userId)
                options[idx].voteCount = options[idx].voterIds.count
            }
            post.pollOptions = options
        }
        HapticService.buttonTap()
    }
}
