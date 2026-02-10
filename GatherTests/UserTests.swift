import XCTest
@testable import Gather

final class UserTests: XCTestCase {

    // MARK: - User Creation

    func testUserCreation() {
        let user = User(name: "Test User")

        XCTAssertFalse(user.id.uuidString.isEmpty)
        XCTAssertEqual(user.name, "Test User")
        XCTAssertNil(user.email)
        XCTAssertNil(user.phone)
        XCTAssertNil(user.avatarURL)
        XCTAssertTrue(user.authProviders.isEmpty)
    }

    func testUserWithFullDetails() {
        let user = User(
            name: "Jane Doe",
            email: "jane@example.com",
            phone: "+1234567890",
            avatarURL: URL(string: "https://example.com/avatar.jpg"),
            authProviders: [.apple, .email]
        )

        XCTAssertEqual(user.name, "Jane Doe")
        XCTAssertEqual(user.email, "jane@example.com")
        XCTAssertEqual(user.phone, "+1234567890")
        XCTAssertNotNil(user.avatarURL)
        XCTAssertEqual(user.authProviders.count, 2)
        XCTAssertTrue(user.authProviders.contains(.apple))
        XCTAssertTrue(user.authProviders.contains(.email))
    }

    // MARK: - User Settings

    func testDefaultUserSettings() {
        let settings = UserSettings()

        XCTAssertEqual(settings.defaultEventPrivacy, "inviteOnly")
        XCTAssertTrue(settings.showMeAsAttending)
        XCTAssertTrue(settings.notificationsEnabled)
        XCTAssertTrue(settings.calendarSyncEnabled)
    }

    func testCustomUserSettings() {
        let settings = UserSettings(
            defaultEventPrivacy: "public",
            showMeAsAttending: false,
            notificationsEnabled: false,
            calendarSyncEnabled: false
        )

        XCTAssertEqual(settings.defaultEventPrivacy, "public")
        XCTAssertFalse(settings.showMeAsAttending)
        XCTAssertFalse(settings.notificationsEnabled)
        XCTAssertFalse(settings.calendarSyncEnabled)
    }

    // MARK: - Auth Providers

    func testAuthProviderRawValues() {
        XCTAssertEqual(AuthProvider.apple.rawValue, "apple")
        XCTAssertEqual(AuthProvider.google.rawValue, "google")
        XCTAssertEqual(AuthProvider.email.rawValue, "email")
    }

    func testAllAuthProviders() {
        let allProviders = AuthProvider.allCases
        XCTAssertEqual(allProviders.count, 3)
        XCTAssertTrue(allProviders.contains(.apple))
        XCTAssertTrue(allProviders.contains(.google))
        XCTAssertTrue(allProviders.contains(.email))
    }
}
