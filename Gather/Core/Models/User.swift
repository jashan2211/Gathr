import Foundation
import SwiftData

// MARK: - User Model

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String?
    var phone: String?
    var avatarURL: URL?
    var authProviders: [AuthProvider]
    var settings: UserSettings
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        email: String? = nil,
        phone: String? = nil,
        avatarURL: URL? = nil,
        authProviders: [AuthProvider] = [],
        settings: UserSettings = UserSettings()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.avatarURL = avatarURL
        self.authProviders = authProviders
        self.settings = settings
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Auth Provider

enum AuthProvider: String, Codable, CaseIterable {
    case apple
    case google
    case email
}

// MARK: - User Settings

struct UserSettings: Codable, Hashable {
    var defaultEventPrivacy: String = "inviteOnly"
    var showMeAsAttending: Bool = true
    var notificationsEnabled: Bool = true
    var calendarSyncEnabled: Bool = true

    init(
        defaultEventPrivacy: String = "inviteOnly",
        showMeAsAttending: Bool = true,
        notificationsEnabled: Bool = true,
        calendarSyncEnabled: Bool = true
    ) {
        self.defaultEventPrivacy = defaultEventPrivacy
        self.showMeAsAttending = showMeAsAttending
        self.notificationsEnabled = notificationsEnabled
        self.calendarSyncEnabled = calendarSyncEnabled
    }
}
