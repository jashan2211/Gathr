import Foundation
import SwiftData

// MARK: - Activity Post Type

enum ActivityPostType: String, Codable, CaseIterable {
    case announcement
    case question
    case answer
    case poll
    case photo
    case update

    var icon: String {
        switch self {
        case .announcement: return "megaphone.fill"
        case .question: return "questionmark.bubble"
        case .answer: return "text.bubble.fill"
        case .poll: return "chart.bar.fill"
        case .photo: return "photo.fill"
        case .update: return "bell.fill"
        }
    }

    var displayName: String {
        switch self {
        case .announcement: return "Announcement"
        case .question: return "Question"
        case .answer: return "Answer"
        case .poll: return "Poll"
        case .photo: return "Photo"
        case .update: return "Update"
        }
    }

    var tintColor: String {
        switch self {
        case .announcement: return "orange"
        case .question: return "blue"
        case .answer: return "green"
        case .poll: return "purple"
        case .photo: return "pink"
        case .update: return "gray"
        }
    }
}

// MARK: - Poll Option

struct PollOption: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var text: String
    var voteCount: Int
    var voterIds: [UUID]

    init(id: UUID = UUID(), text: String, voteCount: Int = 0, voterIds: [UUID] = []) {
        self.id = id
        self.text = text
        self.voteCount = voteCount
        self.voterIds = voterIds
    }
}

// MARK: - Activity Post Model

@Model
final class ActivityPost {
    var id: UUID
    var text: String
    var postType: ActivityPostType
    var createdAt: Date
    var isPinned: Bool = false
    var likes: Int = 0
    var likedByUserIds: [UUID] = []

    // Poll support
    var pollOptions: [PollOption]?
    var allowsMultipleVotes: Bool = false

    // Photo support
    var imageData: Data?

    // Threading
    var parentPostId: UUID?

    // Author info (denormalized for display)
    var authorId: UUID?
    var authorName: String = ""
    var isHostPost: Bool = false

    // Event reference
    var eventId: UUID?

    init(
        id: UUID = UUID(),
        text: String,
        postType: ActivityPostType = .update,
        isPinned: Bool = false,
        pollOptions: [PollOption]? = nil,
        allowsMultipleVotes: Bool = false,
        imageData: Data? = nil,
        parentPostId: UUID? = nil,
        authorId: UUID? = nil,
        authorName: String = "",
        isHostPost: Bool = false,
        eventId: UUID? = nil
    ) {
        self.id = id
        self.text = text
        self.postType = postType
        self.createdAt = Date()
        self.isPinned = isPinned
        self.pollOptions = pollOptions
        self.allowsMultipleVotes = allowsMultipleVotes
        self.imageData = imageData
        self.parentPostId = parentPostId
        self.authorId = authorId
        self.authorName = authorName
        self.isHostPost = isHostPost
        self.eventId = eventId
    }
}

// MARK: - Activity Post Helpers

extension ActivityPost {
    var isReply: Bool {
        parentPostId != nil
    }

    func isLikedBy(userId: UUID) -> Bool {
        likedByUserIds.contains(userId)
    }

    var totalVotes: Int {
        pollOptions?.reduce(0) { $0 + $1.voteCount } ?? 0
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Comment Model (Legacy compatibility)

typealias Comment = ActivityPost

// MARK: - Media Item Model

@Model
final class MediaItem {
    var id: UUID
    var type: MediaType
    var url: URL?
    var imageData: Data?
    var thumbnailURL: URL?
    var caption: String?
    var createdAt: Date

    // Store references as IDs
    var eventId: UUID?
    var uploaderId: UUID?
    var uploaderName: String = ""

    init(
        id: UUID = UUID(),
        type: MediaType = .image,
        url: URL? = nil,
        imageData: Data? = nil,
        thumbnailURL: URL? = nil,
        caption: String? = nil,
        eventId: UUID? = nil,
        uploaderId: UUID? = nil,
        uploaderName: String = ""
    ) {
        self.id = id
        self.type = type
        self.url = url
        self.imageData = imageData
        self.thumbnailURL = thumbnailURL
        self.caption = caption
        self.createdAt = Date()
        self.eventId = eventId
        self.uploaderId = uploaderId
        self.uploaderName = uploaderName
    }
}

// MARK: - Media Type

enum MediaType: String, Codable, CaseIterable {
    case image
    case video

    var icon: String {
        switch self {
        case .image: return "photo"
        case .video: return "video"
        }
    }
}
