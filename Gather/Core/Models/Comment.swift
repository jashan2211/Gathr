import Foundation
import SwiftData

// MARK: - Comment Model

@Model
final class Comment {
    @Attribute(.unique) var id: UUID
    var text: String
    var createdAt: Date

    // Relationships
    var event: Event?
    var author: User?

    @Relationship(deleteRule: .cascade, inverse: \MediaItem.comment)
    var attachments: [MediaItem] = []

    init(
        id: UUID = UUID(),
        text: String,
        event: Event? = nil,
        author: User? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = Date()
        self.event = event
        self.author = author
    }
}

// MARK: - Media Item Model

@Model
final class MediaItem {
    @Attribute(.unique) var id: UUID
    var type: MediaType
    var url: URL
    var thumbnailURL: URL?
    var createdAt: Date

    // Relationships
    var event: Event?
    var uploader: User?
    var comment: Comment?

    init(
        id: UUID = UUID(),
        type: MediaType,
        url: URL,
        thumbnailURL: URL? = nil,
        event: Event? = nil,
        uploader: User? = nil,
        comment: Comment? = nil
    ) {
        self.id = id
        self.type = type
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.createdAt = Date()
        self.event = event
        self.uploader = uploader
        self.comment = comment
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
