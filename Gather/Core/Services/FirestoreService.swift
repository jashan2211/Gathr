import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftData
import os

private let logger = Logger(subsystem: "ca.thebighead.gathr", category: "Firestore")

/// Central access point for Cloud Firestore.
///
/// Phase 2 moves the app's data from on-device SwiftData to Firestore so
/// events, guests and RSVPs are shared across devices. The migration is
/// additive: SwiftData still drives the UI, and Firestore syncs alongside it,
/// so the app keeps working even if a sync fails. Firestore keeps a local
/// cache and works offline by default.
@MainActor
final class FirestoreService {
    static let shared = FirestoreService()

    let db = Firestore.firestore()

    private var usersCollection: CollectionReference { db.collection("users") }
    private var eventsCollection: CollectionReference { db.collection("events") }

    private init() {}

    // MARK: - User Profiles

    /// Upserts the signed-in user's profile at `users/{uid}`. Hosts' names need
    /// to be readable by guests viewing a shared event, so each account keeps a
    /// lightweight public profile document.
    func syncUserProfile(uid: String, name: String, email: String?) {
        var data: [String: Any] = [
            "name": name,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let email, !email.isEmpty {
            data["email"] = email
        }
        usersCollection.document(uid).setData(data, merge: true) { error in
            if let error {
                logger.error("User profile sync failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Events

    /// Uploads (or updates) an event — including its guests and functions — to
    /// Firestore. Fire-and-forget: it never blocks or breaks the UI.
    func pushEvent(_ event: Event) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let document = EventDocument(event: event, ownerUid: uid)
        do {
            try eventsCollection.document(document.id).setData(from: document, merge: true)
        } catch {
            logger.error("Event push failed: \(error.localizedDescription)")
        }
    }

    /// Pushes every event hosted by the signed-in user. Called when the app
    /// goes to the background so guest/RSVP changes made anywhere in the app
    /// reach the cloud without having to instrument every screen.
    func pushHostedEvents(from modelContext: ModelContext) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let hostId = AuthManager.deterministicUUID(from: uid)
        let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.hostId == hostId })
        guard let events = try? modelContext.fetch(descriptor) else { return }
        for event in events {
            pushEvent(event)
        }
    }

    /// Removes an event from Firestore.
    func deleteEvent(id: UUID) {
        eventsCollection.document(id.uuidString).delete { error in
            if let error {
                logger.error("Event delete failed: \(error.localizedDescription)")
            }
        }
    }

    /// Pulls the signed-in user's events from Firestore and inserts any that
    /// aren't on this device yet. Insert-only — it never modifies or deletes
    /// existing local events, so it cannot corrupt on-device data.
    func mergeRemoteEvents(into modelContext: ModelContext) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snapshot = try await eventsCollection
                .whereField("ownerUid", isEqualTo: uid)
                .getDocuments()
            let remoteEvents = snapshot.documents.compactMap { try? $0.data(as: EventDocument.self) }

            let existing = (try? modelContext.fetch(FetchDescriptor<Event>())) ?? []
            let existingIds = Set(existing.map { $0.id })

            var insertedCount = 0
            for document in remoteEvents {
                guard let eventId = UUID(uuidString: document.id),
                      !existingIds.contains(eventId) else { continue }
                modelContext.insert(document.makeEvent())
                insertedCount += 1
            }
            if insertedCount > 0 {
                modelContext.safeSave()
                logger.info("Merged \(insertedCount) event(s) from the cloud.")
            }
        } catch {
            logger.error("Event pull failed: \(error.localizedDescription)")
        }
    }

    /// Fetches a single event by id from Firestore — used when someone opens a
    /// shared invite link to an event they don't host. Inserts it into the
    /// local store so it persists, and returns it.
    func fetchEvent(id: UUID, into modelContext: ModelContext) async -> Event? {
        let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == id })
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        do {
            let snapshot = try await eventsCollection.document(id.uuidString).getDocument()
            guard snapshot.exists,
                  let document = try? snapshot.data(as: EventDocument.self) else {
                return nil
            }
            let event = document.makeEvent()
            modelContext.insert(event)
            modelContext.safeSave()
            return event
        } catch {
            logger.error("Shared event fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Event Firestore Document

/// Codable representation of an `Event` for Firestore. The event, its guests
/// and its functions are stored together in one document. The local hero
/// image is intentionally omitted — image hosting is a later stage.
struct EventDocument: Codable {
    var id: String
    var ownerUid: String
    var hostId: String?
    var title: String
    var eventDescription: String?
    var startDate: Date
    var endDate: Date?
    var timezone: String
    var recurrence: RecurrenceRule?
    var location: EventLocation?
    var capacity: Int?
    var privacy: EventPrivacy
    var guestListVisibility: GuestListVisibility
    var password: String?
    var requiresApproval: Bool
    var category: EventCategory
    var enabledFeaturesRaw: [String]
    var isDraft: Bool
    var createdAt: Date
    var updatedAt: Date
    var guests: [GuestDocument]
    var functions: [FunctionDocument]

    init(event: Event, ownerUid: String) {
        self.id = event.id.uuidString
        self.ownerUid = ownerUid
        self.hostId = event.hostId?.uuidString
        self.title = event.title
        self.eventDescription = event.eventDescription
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.timezone = event.timezone
        self.recurrence = event.recurrence
        self.location = event.location
        self.capacity = event.capacity
        self.privacy = event.privacy
        self.guestListVisibility = event.guestListVisibility
        self.password = event.password
        self.requiresApproval = event.requiresApproval
        self.category = event.category
        self.enabledFeaturesRaw = event.enabledFeaturesRaw
        self.isDraft = event.isDraft
        self.createdAt = event.createdAt
        self.updatedAt = event.updatedAt
        self.guests = event.guests.map { GuestDocument(guest: $0) }
        self.functions = event.functions.map { FunctionDocument(function: $0) }
    }

    /// Builds a fresh SwiftData `Event` (with guests and functions) from this document.
    func makeEvent() -> Event {
        let event = Event(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            eventDescription: eventDescription,
            startDate: startDate,
            endDate: endDate,
            timezone: timezone,
            recurrence: recurrence,
            location: location,
            capacity: capacity,
            privacy: privacy,
            guestListVisibility: guestListVisibility,
            password: password,
            requiresApproval: requiresApproval,
            category: category,
            hostId: hostId.flatMap { UUID(uuidString: $0) },
            isDraft: isDraft
        )
        event.enabledFeaturesRaw = enabledFeaturesRaw
        event.createdAt = createdAt
        event.updatedAt = updatedAt
        event.guests = guests.map { $0.makeGuest() }
        event.functions = functions.map { $0.makeFunction() }
        return event
    }
}

// MARK: - Guest Firestore Document

struct GuestDocument: Codable {
    var id: String
    var name: String
    var email: String?
    var phone: String?
    var status: RSVPStatus
    var plusOneCount: Int
    var role: GuestRole
    var metadata: GuestMetadata?
    var invitedAt: Date
    var respondedAt: Date?
    var inviteSentAt: Date?
    var inviteSentVia: InviteChannel?
    var userId: String?
    var partyMembers: [PartyMemberDocument]

    init(guest: Guest) {
        self.id = guest.id.uuidString
        self.name = guest.name
        self.email = guest.email
        self.phone = guest.phone
        self.status = guest.status
        self.plusOneCount = guest.plusOneCount
        self.role = guest.role
        self.metadata = guest.metadata
        self.invitedAt = guest.invitedAt
        self.respondedAt = guest.respondedAt
        self.inviteSentAt = guest.inviteSentAt
        self.inviteSentVia = guest.inviteSentVia
        self.userId = guest.userId?.uuidString
        self.partyMembers = guest.partyMembers.map { PartyMemberDocument(member: $0) }
    }

    func makeGuest() -> Guest {
        let guest = Guest(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            email: email,
            phone: phone,
            status: status,
            plusOneCount: plusOneCount,
            role: role,
            metadata: metadata,
            userId: userId.flatMap { UUID(uuidString: $0) }
        )
        guest.invitedAt = invitedAt
        guest.respondedAt = respondedAt
        guest.inviteSentAt = inviteSentAt
        guest.inviteSentVia = inviteSentVia
        guest.partyMembers = partyMembers.map { $0.makePartyMember() }
        return guest
    }
}

// MARK: - Party Member Firestore Document

struct PartyMemberDocument: Codable {
    var id: String
    var name: String
    var relationship: PartyRelationship?
    var dietaryRestrictions: String?
    var createdAt: Date

    init(member: PartyMember) {
        self.id = member.id.uuidString
        self.name = member.name
        self.relationship = member.relationship
        self.dietaryRestrictions = member.dietaryRestrictions
        self.createdAt = member.createdAt
    }

    func makePartyMember() -> PartyMember {
        let member = PartyMember(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            relationship: relationship,
            dietaryRestrictions: dietaryRestrictions
        )
        member.createdAt = createdAt
        return member
    }
}

// MARK: - Function Firestore Document

struct FunctionDocument: Codable {
    var id: String
    var name: String
    var functionDescription: String?
    var date: Date
    var endTime: Date?
    var location: EventLocation?
    var dressCode: DressCode?
    var customDressCode: String?
    var sortOrder: Int
    var eventId: String
    var createdAt: Date
    var updatedAt: Date
    var invites: [InviteDocument]

    init(function: EventFunction) {
        self.id = function.id.uuidString
        self.name = function.name
        self.functionDescription = function.functionDescription
        self.date = function.date
        self.endTime = function.endTime
        self.location = function.location
        self.dressCode = function.dressCode
        self.customDressCode = function.customDressCode
        self.sortOrder = function.sortOrder
        self.eventId = function.eventId.uuidString
        self.createdAt = function.createdAt
        self.updatedAt = function.updatedAt
        self.invites = function.invites.map { InviteDocument(invite: $0) }
    }

    func makeFunction() -> EventFunction {
        let function = EventFunction(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            functionDescription: functionDescription,
            date: date,
            endTime: endTime,
            location: location,
            dressCode: dressCode,
            customDressCode: customDressCode,
            sortOrder: sortOrder,
            eventId: UUID(uuidString: eventId) ?? UUID()
        )
        function.createdAt = createdAt
        function.updatedAt = updatedAt
        function.invites = invites.map { $0.makeInvite() }
        return function
    }
}

// MARK: - Function Invite Firestore Document

struct InviteDocument: Codable {
    var id: String
    var guestId: String
    var functionId: String
    var inviteStatus: InviteStatus
    var sentAt: Date?
    var sentVia: InviteChannel?
    var response: RSVPResponse?
    var partySize: Int
    var notes: String?
    var respondedAt: Date?
    var createdAt: Date

    init(invite: FunctionInvite) {
        self.id = invite.id.uuidString
        self.guestId = invite.guestId.uuidString
        self.functionId = invite.functionId.uuidString
        self.inviteStatus = invite.inviteStatus
        self.sentAt = invite.sentAt
        self.sentVia = invite.sentVia
        self.response = invite.response
        self.partySize = invite.partySize
        self.notes = invite.notes
        self.respondedAt = invite.respondedAt
        self.createdAt = invite.createdAt
    }

    func makeInvite() -> FunctionInvite {
        let invite = FunctionInvite(
            id: UUID(uuidString: id) ?? UUID(),
            guestId: UUID(uuidString: guestId) ?? UUID(),
            functionId: UUID(uuidString: functionId) ?? UUID(),
            inviteStatus: inviteStatus,
            sentAt: sentAt,
            sentVia: sentVia,
            response: response,
            partySize: partySize,
            notes: notes,
            respondedAt: respondedAt
        )
        invite.createdAt = createdAt
        return invite
    }
}
