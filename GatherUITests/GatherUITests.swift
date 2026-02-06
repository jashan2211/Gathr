import XCTest

final class GatherUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Auth Flow Tests

    func testAuthScreenAppears() throws {
        // Check for sign-in buttons
        XCTAssertTrue(app.buttons["Sign in with Apple"].exists || app.staticTexts["Gather"].exists)
    }

    // MARK: - Tab Navigation Tests

    func testTabBarNavigation() throws {
        // Skip if not authenticated
        guard app.tabBars.buttons["Home"].exists else {
            throw XCTSkip("User not authenticated")
        }

        // Test tab navigation
        let homeTab = app.tabBars.buttons["Home"]
        let myEventsTab = app.tabBars.buttons["My Events"]
        let contactsTab = app.tabBars.buttons["Contacts"]
        let profileTab = app.tabBars.buttons["Profile"]

        XCTAssertTrue(homeTab.exists)
        XCTAssertTrue(myEventsTab.exists)
        XCTAssertTrue(contactsTab.exists)
        XCTAssertTrue(profileTab.exists)

        // Navigate through tabs
        myEventsTab.tap()
        XCTAssertTrue(app.navigationBars["My Events"].exists)

        contactsTab.tap()
        XCTAssertTrue(app.navigationBars["Contacts"].exists)

        profileTab.tap()
        XCTAssertTrue(app.navigationBars["Profile"].exists)

        homeTab.tap()
        XCTAssertTrue(app.navigationBars["Home"].exists)
    }

    // MARK: - Create Event Tests

    func testCreateEventButton() throws {
        // Skip if not authenticated
        guard app.buttons["Create Event"].exists else {
            throw XCTSkip("Create button not found")
        }

        app.buttons["Create Event"].tap()

        // Verify create event sheet appears
        XCTAssertTrue(app.navigationBars["Create Event"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
    }

    func testCreateEventValidation() throws {
        // Skip if not authenticated
        guard app.buttons["Create Event"].exists else {
            throw XCTSkip("Create button not found")
        }

        app.buttons["Create Event"].tap()

        // Create button should be disabled without title
        let createButton = app.buttons["Create"]
        XCTAssertFalse(createButton.isEnabled)

        // Enter title
        let titleField = app.textFields["Give your event a name"]
        titleField.tap()
        titleField.typeText("Test Event")

        // Create button should now be enabled
        XCTAssertTrue(createButton.isEnabled)
    }

    // MARK: - RSVP Flow Tests

    func testRSVPOptions() throws {
        // This test requires an event to be visible
        // Skip if no events are available
        guard app.buttons["RSVP"].exists else {
            throw XCTSkip("No RSVP button found")
        }

        app.buttons["RSVP"].tap()

        // Verify RSVP options appear
        XCTAssertTrue(app.staticTexts["Will you be attending?"].exists)
        XCTAssertTrue(app.staticTexts["Going"].exists)
        XCTAssertTrue(app.staticTexts["Maybe"].exists)
        XCTAssertTrue(app.staticTexts["Can't Go"].exists)
    }

    // MARK: - Profile Tests

    func testProfileSettings() throws {
        // Skip if not authenticated
        guard app.tabBars.buttons["Profile"].exists else {
            throw XCTSkip("Profile tab not found")
        }

        app.tabBars.buttons["Profile"].tap()

        // Check for settings options
        XCTAssertTrue(app.staticTexts["Notifications"].exists)
        XCTAssertTrue(app.staticTexts["Privacy"].exists)
        XCTAssertTrue(app.buttons["Sign Out"].exists)
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() throws {
        // Check that key elements have accessibility labels
        let createButton = app.buttons["Create Event"]
        if createButton.exists {
            XCTAssertFalse(createButton.label.isEmpty)
        }
    }

    // MARK: - Performance Tests

    func testLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
