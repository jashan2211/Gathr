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
            // Full event (owner-readable only) — carries guest contact info.
            try eventsCollection.document(document.id).setData(from: document, merge: true)
            // Sanitized public projection for invitees (web + non-host app):
            // title/date/location only — no guest list, no contact info. This
            // is what an invite link reads, so PII never leaves the owner.
            let hostName = Auth.auth().currentUser?.displayName
            let publicDoc = EventPublicDocument(event: event, ownerUid: uid, hostName: hostName)
            try eventsCollection.document(document.id)
                .collection("public").document("info")
                .setData(from: publicDoc, merge: true)
        } catch {
            logger.error("Event push failed: \(error.localizedDescription)")
        }
    }

    // MARK: - RSVPs (cross-user)

    /// Writes a guest's RSVP to `events/{eventId}/rsvps/{guestId}`. This is the
    /// one channel a guest can write to — the event doc itself is owner-only.
    /// Called both from the in-app RSVP sheet and (in JS) from the web invite
    /// page, so an invited guest can respond with or without the app.
    func submitRSVP(eventId: UUID, guestId: UUID, status: RSVPStatus, partySize: Int, name: String, note: String?) {
        let data: [String: Any] = [
            "guestId": guestId.uuidString,
            "status": status.rawValue,
            "partySize": max(0, partySize),
            "name": name,
            "note": note ?? "",
            "respondedAt": FieldValue.serverTimestamp(),
            "source": "app"
        ]
        eventsCollection.document(eventId.uuidString)
            .collection("rsvps").document(guestId.uuidString)
            .setData(data, merge: true) { error in
                if let error {
                    logger.error("RSVP submit failed: \(error.localizedDescription)")
                }
            }
    }

    /// Pulls guest responses for a hosted event and merges them into the local
    /// guest list. A remote response wins only when it's newer than the local
    /// one, so a host's manual edit isn't clobbered by a stale web RSVP.
    func fetchRSVPs(for event: Event, into modelContext: ModelContext) async {
        guard Auth.auth().currentUser != nil else { return }
        do {
            let snapshot = try await eventsCollection.document(event.id.uuidString)
                .collection("rsvps").getDocuments()
            var changed = false
            for doc in snapshot.documents {
                let data = doc.data()
                guard let guestIdStr = data["guestId"] as? String,
                      let guestId = UUID(uuidString: guestIdStr),
                      let statusStr = data["status"] as? String,
                      let status = RSVPStatus(rawValue: statusStr),
                      let guest = event.guests.first(where: { $0.id == guestId }) else { continue }

                let remoteDate = (data["respondedAt"] as? Timestamp)?.dateValue() ?? Date()
                if let localDate = guest.respondedAt, localDate >= remoteDate { continue }

                guest.status = status
                guest.plusOneCount = data["partySize"] as? Int ?? guest.plusOneCount
                guest.respondedAt = remoteDate
                if let note = data["note"] as? String, !note.isEmpty {
                    if guest.metadata != nil { guest.metadata?.notes = note }
                    else { guest.metadata = GuestMetadata(notes: note) }
                }
                changed = true
            }
            if changed {
                modelContext.safeSave()
                logger.info("Merged guest RSVPs from the cloud.")
            }
        } catch {
            logger.error("RSVP fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Invited Events (a guest's personal index)

    /// Records, under `users/{uid}/invitedEvents/{eventId}`, that the signed-in
    /// user is invited to an event — so their invitations follow their account
    /// across devices and reinstalls, not just the device that opened the link.
    func recordInvitedEvent(_ event: Event, guestId: UUID, status: RSVPStatus) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let data: [String: Any] = [
            "eventId": event.id.uuidString,
            "guestId": guestId.uuidString,
            "title": event.title,
            "startDate": event.startDate,
            "status": status.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        usersCollection.document(uid).collection("invitedEvents")
            .document(event.id.uuidString)
            .setData(data, merge: true) { error in
                if let error {
                    logger.error("Invited-event index write failed: \(error.localizedDescription)")
                }
            }
    }

    /// Pulls the user's invited-events index and makes sure each event exists
    /// locally with a guest entry tied to this account, so invitations show up
    /// in Home and Calendar on any device they sign in to.
    func fetchInvitedEvents(into modelContext: ModelContext) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let myUserId = AuthManager.deterministicUUID(from: uid)
        let myName = Auth.auth().currentUser?.displayName ?? "You"
        do {
            let snapshot = try await usersCollection.document(uid).collection("invitedEvents").getDocuments()
            var changed = false
            for doc in snapshot.documents {
                let data = doc.data()
                guard let eventIdStr = data["eventId"] as? String, let eventId = UUID(uuidString: eventIdStr),
                      let guestIdStr = data["guestId"] as? String, let guestId = UUID(uuidString: guestIdStr) else { continue }
                let status = (data["status"] as? String).flatMap(RSVPStatus.init(rawValue:)) ?? .pending

                var event = (try? modelContext.fetch(FetchDescriptor<Event>(predicate: #Predicate { $0.id == eventId })))?.first
                if event == nil {
                    event = await fetchEvent(id: eventId, into: modelContext)
                }
                guard let event else { continue }

                if ensureInvitedGuest(on: event, guestId: guestId, userId: myUserId, name: myName, status: status) {
                    changed = true
                }
            }
            if changed { modelContext.safeSave() }
        } catch {
            logger.error("Invited-events pull failed: \(error.localizedDescription)")
        }
    }

    /// Ensures a local guest entry exists on `event` for this account, so the
    /// event shows in the signed-in user's Home/Calendar. Returns whether it
    /// changed anything.
    @discardableResult
    func ensureInvitedGuest(on event: Event, guestId: UUID, userId: UUID, name: String, status: RSVPStatus) -> Bool {
        if let existing = event.guests.first(where: { $0.id == guestId }) {
            if existing.userId == nil {
                existing.userId = userId
                return true
            }
            return false
        }
        let guest = Guest(id: guestId, name: name, status: status, userId: userId)
        event.guests.append(guest)
        return true
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

    /// Fetches a single event by id for someone opening a shared invite link to
    /// an event they don't host. Reads the sanitized public projection (no other
    /// guests' contact info), inserts it locally so it persists, and returns it.
    func fetchEvent(id: UUID, into modelContext: ModelContext) async -> Event? {
        let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == id })
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        do {
            let snapshot = try await eventsCollection.document(id.uuidString)
                .collection("public").document("info").getDocument()
            guard snapshot.exists,
                  let document = try? snapshot.data(as: EventPublicDocument.self) else {
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

// MARK: - Public Event Projection

/// The slice of an event that's safe for invitees to read — no guest list and
/// no contact info. Lives at `events/{id}/public/info`, readable by any signed-in
/// user (including anonymous web visitors); the full `EventDocument` stays
/// owner-only.
struct EventPublicDocument: Codable {
    var id: String
    var ownerUid: String
    var title: String
    var eventDescription: String?
    var startDate: Date
    var endDate: Date?
    var location: EventLocation?
    var category: EventCategory
    var capacity: Int?
    var hostName: String?
    var isDraft: Bool
    var functions: [PublicFunctionDocument]

    init(event: Event, ownerUid: String, hostName: String?) {
        self.id = event.id.uuidString
        self.ownerUid = ownerUid
        self.title = event.title
        self.eventDescription = event.eventDescription
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.location = event.location
        self.category = event.category
        self.capacity = event.capacity
        self.hostName = hostName
        self.isDraft = event.isDraft
        self.functions = event.functions
            .sorted { $0.date < $1.date }
            .map { PublicFunctionDocument(function: $0) }
    }

    func makeEvent() -> Event {
        let event = Event(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            eventDescription: eventDescription,
            startDate: startDate,
            endDate: endDate,
            location: location,
            capacity: capacity,
            category: category
        )
        event.functions = functions.map { $0.makeFunction(eventId: event.id) }
        return event
    }
}

struct PublicFunctionDocument: Codable {
    var id: String
    var name: String
    var functionDescription: String?
    var date: Date
    var endTime: Date?
    var location: EventLocation?

    init(function: EventFunction) {
        self.id = function.id.uuidString
        self.name = function.name
        self.functionDescription = function.functionDescription
        self.date = function.date
        self.endTime = function.endTime
        self.location = function.location
    }

    func makeFunction(eventId: UUID) -> EventFunction {
        EventFunction(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            functionDescription: functionDescription,
            date: date,
            endTime: endTime,
            location: location,
            eventId: eventId
        )
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
