import XCTest
@testable import Gather

final class EventTests: XCTestCase {

    // MARK: - Event Creation

    func testEventCreation() {
        let event = Event(
            title: "Test Event",
            startDate: Date()
        )

        XCTAssertFalse(event.id.uuidString.isEmpty)
        XCTAssertEqual(event.title, "Test Event")
        XCTAssertNil(event.eventDescription)
        XCTAssertNil(event.capacity)
        XCTAssertEqual(event.privacy, .inviteOnly)
        XCTAssertEqual(event.guestListVisibility, .visible)
        XCTAssertFalse(event.requiresApproval)
    }

    func testEventWithAllFields() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600)
        let location = EventLocation(name: "Test Location", address: "123 Main St")

        let event = Event(
            title: "Full Event",
            eventDescription: "A complete event with all fields",
            startDate: startDate,
            endDate: endDate,
            location: location,
            capacity: 50,
            privacy: .publicEvent,
            guestListVisibility: .countOnly,
            requiresApproval: true
        )

        XCTAssertEqual(event.title, "Full Event")
        XCTAssertEqual(event.eventDescription, "A complete event with all fields")
        XCTAssertEqual(event.capacity, 50)
        XCTAssertEqual(event.privacy, .publicEvent)
        XCTAssertEqual(event.guestListVisibility, .countOnly)
        XCTAssertTrue(event.requiresApproval)
        XCTAssertEqual(event.location?.name, "Test Location")
    }

    // MARK: - Event Status

    func testUpcomingEvent() {
        let event = Event(
            title: "Future Event",
            startDate: Date().addingTimeInterval(86400) // Tomorrow
        )

        XCTAssertTrue(event.isUpcoming)
        XCTAssertFalse(event.isPast)
        XCTAssertFalse(event.isOngoing)
    }

    func testPastEvent() {
        let event = Event(
            title: "Past Event",
            startDate: Date().addingTimeInterval(-86400), // Yesterday
            endDate: Date().addingTimeInterval(-82800) // Yesterday + 1 hour
        )

        XCTAssertFalse(event.isUpcoming)
        XCTAssertTrue(event.isPast)
        XCTAssertFalse(event.isOngoing)
    }

    // MARK: - Capacity

    func testEventCapacity() {
        let event = Event(
            title: "Limited Event",
            startDate: Date(),
            capacity: 10
        )

        XCTAssertEqual(event.capacity, 10)
        XCTAssertEqual(event.spotsRemaining, 10)
        XCTAssertFalse(event.isFull)
    }

    func testEventWithoutCapacity() {
        let event = Event(
            title: "Unlimited Event",
            startDate: Date()
        )

        XCTAssertNil(event.capacity)
        XCTAssertNil(event.spotsRemaining)
        XCTAssertFalse(event.isFull)
    }

    // MARK: - Privacy

    func testEventPrivacyDisplayNames() {
        XCTAssertEqual(EventPrivacy.publicEvent.displayName, "Public")
        XCTAssertEqual(EventPrivacy.unlisted.displayName, "Unlisted")
        XCTAssertEqual(EventPrivacy.inviteOnly.displayName, "Invite Only")
    }

    func testGuestListVisibilityDisplayNames() {
        XCTAssertEqual(GuestListVisibility.visible.displayName, "Show guest list")
        XCTAssertEqual(GuestListVisibility.countOnly.displayName, "Show count only")
        XCTAssertEqual(GuestListVisibility.hidden.displayName, "Hide completely")
    }
}
