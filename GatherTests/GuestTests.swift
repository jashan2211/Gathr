import XCTest
@testable import Gather

final class GuestTests: XCTestCase {

    // MARK: - Guest Creation

    func testGuestCreation() {
        let guest = Guest(name: "John Doe")

        XCTAssertFalse(guest.id.uuidString.isEmpty)
        XCTAssertEqual(guest.name, "John Doe")
        XCTAssertEqual(guest.status, .pending)
        XCTAssertEqual(guest.plusOneCount, 0)
        XCTAssertEqual(guest.role, .guest)
        XCTAssertNil(guest.metadata)
        XCTAssertFalse(guest.hasResponded)
    }

    func testGuestWithFullDetails() {
        let guest = Guest(
            name: "Jane Smith",
            email: "jane@example.com",
            phone: "+1234567890",
            status: .attending,
            plusOneCount: 2,
            role: .vip
        )

        XCTAssertEqual(guest.name, "Jane Smith")
        XCTAssertEqual(guest.email, "jane@example.com")
        XCTAssertEqual(guest.phone, "+1234567890")
        XCTAssertEqual(guest.status, .attending)
        XCTAssertEqual(guest.plusOneCount, 2)
        XCTAssertEqual(guest.role, .vip)
    }

    // MARK: - Headcount

    func testTotalHeadcount() {
        let soloGuest = Guest(name: "Solo")
        XCTAssertEqual(soloGuest.totalHeadcount, 1)

        let guestWithPlusOnes = Guest(name: "Group", plusOneCount: 3)
        XCTAssertEqual(guestWithPlusOnes.totalHeadcount, 4)
    }

    // MARK: - Display Contact

    func testDisplayContact() {
        let guestWithEmail = Guest(name: "Email Person", email: "test@example.com")
        XCTAssertEqual(guestWithEmail.displayContact, "test@example.com")

        let guestWithPhone = Guest(name: "Phone Person", phone: "+1234567890")
        XCTAssertEqual(guestWithPhone.displayContact, "+1234567890")

        let guestWithBoth = Guest(name: "Both", email: "both@example.com", phone: "+1234567890")
        XCTAssertEqual(guestWithBoth.displayContact, "both@example.com") // Email takes priority

        let guestWithNeither = Guest(name: "Anonymous")
        XCTAssertNil(guestWithNeither.displayContact)
    }

    // MARK: - RSVP Status

    func testRSVPStatusDisplayNames() {
        XCTAssertEqual(RSVPStatus.pending.displayName, "Pending")
        XCTAssertEqual(RSVPStatus.attending.displayName, "Going")
        XCTAssertEqual(RSVPStatus.maybe.displayName, "Maybe")
        XCTAssertEqual(RSVPStatus.declined.displayName, "Can't Go")
        XCTAssertEqual(RSVPStatus.waitlisted.displayName, "Waitlisted")
    }

    func testRSVPStatusIcons() {
        XCTAssertEqual(RSVPStatus.pending.icon, "clock")
        XCTAssertEqual(RSVPStatus.attending.icon, "checkmark.circle.fill")
        XCTAssertEqual(RSVPStatus.maybe.icon, "questionmark.circle.fill")
        XCTAssertEqual(RSVPStatus.declined.icon, "xmark.circle.fill")
        XCTAssertEqual(RSVPStatus.waitlisted.icon, "list.bullet")
    }

    // MARK: - Guest Roles

    func testGuestRoleDisplayNames() {
        XCTAssertEqual(GuestRole.guest.displayName, "Guest")
        XCTAssertEqual(GuestRole.vip.displayName, "VIP")
        XCTAssertEqual(GuestRole.cohost.displayName, "Co-host")
        XCTAssertEqual(GuestRole.vendor.displayName, "Vendor")
    }

    // MARK: - Metadata

    func testGuestMetadata() {
        let metadata = GuestMetadata(
            mealChoice: "Vegetarian",
            dietaryRestrictions: "Gluten-free",
            notes: "Seated at table 5",
            assignedTasks: ["Bring cake", "Help with setup"]
        )

        let guest = Guest(name: "Meta Guest", metadata: metadata)

        XCTAssertEqual(guest.metadata?.mealChoice, "Vegetarian")
        XCTAssertEqual(guest.metadata?.dietaryRestrictions, "Gluten-free")
        XCTAssertEqual(guest.metadata?.notes, "Seated at table 5")
        XCTAssertEqual(guest.metadata?.assignedTasks?.count, 2)
    }
}
