import Foundation
import SwiftData

// MARK: - Comment Model

@Model
final class Comment {
    @Attribute(.unique) var id: UUID
    var text: String
    var createdAt: Date

    // Store references as IDs
    var eventId: UUID?
    var authorId: UUID?

    init(
        id: UUID = UUID(),
        text: String,
        eventId: UUID? = nil,
        authorId: UUID? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = Date()
        self.eventId = eventId
        self.authorId = authorId
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

    // Store references as IDs
    var eventId: UUID?
    var uploaderId: UUID?

    init(
        id: UUID = UUID(),
        type: MediaType,
        url: URL,
        thumbnailURL: URL? = nil,
        eventId: UUID? = nil,
        uploaderId: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.createdAt = Date()
        self.eventId = eventId
        self.uploaderId = uploaderId
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
