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
        // Tab bar is a custom floating bar; tabs are regular buttons with accessibility labels
        guard app.buttons["Going"].exists else {
            throw XCTSkip("User not authenticated")
        }

        // Test tab navigation
        let goingTab = app.buttons["Going"]
        let myEventsTab = app.buttons["My Events"]
        let exploreTab = app.buttons["Explore"]
        let profileTab = app.buttons["Profile"]

        XCTAssertTrue(goingTab.exists)
        XCTAssertTrue(myEventsTab.exists)
        XCTAssertTrue(exploreTab.exists)
        XCTAssertTrue(profileTab.exists)

        // Navigate through tabs
        myEventsTab.tap()
        XCTAssertTrue(app.navigationBars["My Events"].exists)

        exploreTab.tap()
        // ExploreView uses an empty navigationTitle with inline search
        XCTAssertTrue(exploreTab.isSelected)

        profileTab.tap()
        XCTAssertTrue(app.navigationBars["Profile"].exists)

        goingTab.tap()
        XCTAssertTrue(app.navigationBars["Going"].exists)
    }

    // MARK: - Create Event Tests

    func testCreateEventButton() throws {
        // Skip if not authenticated
        guard app.buttons["Create New Event"].exists else {
            throw XCTSkip("Create button not found")
        }

        app.buttons["Create New Event"].tap()

        // Verify create event sheet appears
        XCTAssertTrue(app.navigationBars["New Event"].exists)
    }

    func testCreateEventValidation() throws {
        // Skip if not authenticated
        guard app.buttons["Create New Event"].exists else {
            throw XCTSkip("Create button not found")
        }

        app.buttons["Create New Event"].tap()

        // Create Event button should be disabled without title
        let createButton = app.buttons["Create Event"]
        XCTAssertFalse(createButton.isEnabled)

        // Enter title
        let titleField = app.textFields["Give your event a vibe..."]
        titleField.tap()
        titleField.typeText("Test Event")

        // Create Event button should now be enabled
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
        // Tab bar is a custom floating bar; tabs are regular buttons
        guard app.buttons["Profile"].exists else {
            throw XCTSkip("Profile tab not found")
        }

        app.buttons["Profile"].tap()

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
