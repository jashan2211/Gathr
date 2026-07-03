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
        // Content-only: EventDetailView owns the page scroll.
        Group {
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
            .horizontalPadding()
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
                    FirestoreService.shared.pushActivityPost(post)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            // Pull the shared activity feed so posts, likes, and poll votes from
            // other attendees show up.
            await FirestoreService.shared.fetchActivity(for: event, into: modelContext)
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

            // Composer button — 44pt tap target for one-handed use
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
                    .background(Color.gatherElevated)
                    .clipShape(Capsule())
                    .frame(minHeight: Layout.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityHint("Opens the composer")

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
                        .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("New post")
            }
        }
        .padding(Spacing.md)
        .surfaceCard()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        GatherEmptyState(
            icon: "bubble.left.and.bubble.right",
            title: "No Activity Yet",
            message: isHost
                ? "Post an announcement or create a poll to engage your guests"
                : "Be the first to ask a question about this event",
            actionTitle: "Start the conversation",
            action: {
                composerType = isHost ? .announcement : .question
                replyingTo = nil
                HapticService.buttonTap()
                showComposer = true
            }
        )
        .padding(.vertical, Spacing.xl)
    }

    // MARK: - Helpers

    private func repliesFor(_ post: ActivityPost) -> [ActivityPost] {
        eventPosts
            .filter { $0.parentPostId == post.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func toggleLike(_ post: ActivityPost) {
        guard let userId = authManager.currentUser?.id else { return }
        let nowLiked: Bool
        if post.likedByUserIds.contains(userId) {
            post.likedByUserIds.removeAll { $0 == userId }
            post.likes = max(0, post.likes - 1)
            nowLiked = false
        } else {
            post.likedByUserIds.append(userId)
            post.likes += 1
            nowLiked = true
        }
        modelContext.safeSave()
        HapticService.buttonTap()
        if let eventId = post.eventId {
            FirestoreService.shared.setActivityLike(eventId: eventId, postId: post.id, userId: userId, liked: nowLiked)
        }
    }

    private func togglePin(_ post: ActivityPost) {
        post.isPinned.toggle()
        modelContext.safeSave()
        HapticService.buttonTap()
        FirestoreService.shared.pushActivityPost(post)
    }

    private func canDelete(_ post: ActivityPost) -> Bool {
        isHost || post.authorId == authManager.currentUser?.id
    }

    private func deletePost(_ post: ActivityPost) {
        // Delete replies first (tombstone remotely so the removal propagates).
        let replies = repliesFor(post)
        let eventId = post.eventId
        for reply in replies {
            if let eventId { FirestoreService.shared.deleteActivityPost(eventId: eventId, postId: reply.id) }
            modelContext.delete(reply)
        }
        if let eventId { FirestoreService.shared.deleteActivityPost(eventId: eventId, postId: post.id) }
        modelContext.delete(post)
        modelContext.safeSave()
    }

    private func vote(on post: ActivityPost, optionId: UUID) {
        guard let userId = authManager.currentUser?.id,
              var options = post.pollOptions else { return }

        var addTo: UUID?
        var removeFrom: [UUID] = []

        // Check if already voted on this option
        if let idx = options.firstIndex(where: { $0.id == optionId }) {
            if options[idx].voterIds.contains(userId) {
                // Remove vote
                options[idx].voterIds.removeAll { $0 == userId }
                options[idx].voteCount = max(0, options[idx].voteCount - 1)
                removeFrom = [optionId]
            } else {
                // If single vote, remove from the options the user already picked
                if !post.allowsMultipleVotes {
                    for i in options.indices where options[i].voterIds.contains(userId) {
                        removeFrom.append(options[i].id)
                        options[i].voterIds.removeAll { $0 == userId }
                        options[i].voteCount = options[i].voterIds.count
                    }
                }
                // Add vote
                options[idx].voterIds.append(userId)
                options[idx].voteCount = options[idx].voterIds.count
                addTo = optionId
            }
            post.pollOptions = options
        }
        modelContext.safeSave()
        HapticService.buttonTap()

        if let eventId = post.eventId, addTo != nil || !removeFrom.isEmpty {
            FirestoreService.shared.updateActivityVote(
                eventId: eventId, postId: post.id, addTo: addTo, removeFrom: removeFrom, userId: userId)
        }
    }
}
