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
        // The auth screen only appears when there's no restored session. With a
        // persisted sign-in the app shows onboarding or the main tab bar
        // instead — both are valid states, so skip rather than fail there.
        // waitForExistence also absorbs the auth screen's entrance animation.
        let signInButton = app.buttons["Sign in with Apple"]
        guard signInButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Session restored — auth screen not shown")
        }
        XCTAssertTrue(app.staticTexts["Gather"].exists)
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

// MARK: - Screenshot Tour

/// Walks the app's main surfaces and attaches a screenshot at each stop.
/// Used to visually verify the design language across screens — extract with
/// `xcrun xcresulttool export attachments --path <xcresult> --output-path <dir>`.
/// Every stop is guarded so a missing surface skips rather than fails the tour.
final class ScreenshotTourUITests: XCTestCase {

    func testScreenshotTour() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()

        // Sign in with the demo account when signed out.
        let demoButton = app.buttons["Demo Sign In"]
        if demoButton.waitForExistence(timeout: 5) {
            snap(app, "00_auth")
            demoButton.tap()
        }

        // First run shows onboarding — capture it, then skip through.
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 8) {
            snap(app, "00b_onboarding")
            skip.tap()
        } else {
            let getStarted = app.buttons["Get Started"]
            if getStarted.waitForExistence(timeout: 2) {
                snap(app, "00b_onboarding")
                getStarted.tap()
            }
        }

        let goingTab = app.buttons["Going"]
        guard goingTab.waitForExistence(timeout: 25) else {
            snap(app, "zz_stuck")
            throw XCTSkip("Main tab bar never appeared — demo sign-in may need network")
        }
        sleep(1)
        snap(app, "01_going")

        tapIfPresent(app.buttons["My Events"]); sleep(1)
        snap(app, "02_my_events")

        tapIfPresent(app.buttons["Explore"]); sleep(1)
        snap(app, "03_explore")

        tapIfPresent(app.buttons["Profile"]); sleep(1)
        snap(app, "04_profile")

        // Create Event wizard — walk all four steps and create a real event.
        // With events the entry point is "Create New Event"; on an empty
        // account it's the empty state's "Create Event" CTA.
        tapIfPresent(app.buttons["My Events"]); sleep(1)
        var create = app.buttons["Create New Event"]
        if !create.waitForExistence(timeout: 3) {
            create = app.buttons["Create Event"]
        }
        if create.waitForExistence(timeout: 3) {
            create.tap()
            sleep(1)
            snap(app, "05_create_step1")

            let titleField = app.textFields["Give your event a vibe..."]
            if titleField.waitForExistence(timeout: 3) {
                titleField.tap()
                titleField.typeText("Rooftop Birthday Bash")
            }

            // The same wizard button advances steps and finally submits —
            // matched by identifier to avoid colliding with the My Events
            // empty-state "Create Event" button behind the sheet.
            let wizardPrimary = app.buttons["wizardPrimaryButton"]
            if wizardPrimary.waitForExistence(timeout: 3), wizardPrimary.isEnabled {
                wizardPrimary.tap(); sleep(1)
                snap(app, "06_create_step2")

                if wizardPrimary.isEnabled {
                    wizardPrimary.tap(); sleep(1)
                    snap(app, "07_create_step3")
                }
                if wizardPrimary.exists, wizardPrimary.isEnabled {
                    wizardPrimary.tap(); sleep(1)
                    snap(app, "08_create_step4")
                }
                if wizardPrimary.exists, wizardPrimary.isEnabled {
                    wizardPrimary.tap()
                    sleep(2)
                    snap(app, "09_my_events_with_event")
                }
            }
        }

        // Open the event detail and tour its tabs.
        let eventCard = app.staticTexts["Rooftop Birthday Bash"].firstMatch
        if eventCard.waitForExistence(timeout: 5) {
            eventCard.tap()
            sleep(2)
            snap(app, "10_event_detail_overview")

            for (tab, name) in [("Guests", "11_event_detail_guests"),
                                ("Functions", "12_event_detail_functions"),
                                ("Finance", "13_event_detail_finance"),
                                ("Activity", "14_event_detail_activity")] {
                let tabButton = app.buttons[tab]
                if tabButton.exists {
                    tabButton.tap(); sleep(1)
                    snap(app, name)
                }
            }
        }
    }

    private func tapIfPresent(_ element: XCUIElement) {
        if element.waitForExistence(timeout: 3) { element.tap() }
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
