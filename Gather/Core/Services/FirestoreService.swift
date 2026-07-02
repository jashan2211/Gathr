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
    private var discoverCollection: CollectionReference { db.collection("discover") }

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

            // Discovery card: a truly public, non-draft event gets a lightweight
            // top-level card at `discover/{eventId}` so it can surface in Explore
            // for other users. Anything else (private/unlisted, or a draft) has
            // its card removed so it stops showing.
            if event.privacy == .publicEvent && !event.isDraft {
                let card = DiscoverCard(event: event, ownerUid: uid, hostName: hostName)
                try discoverCollection.document(document.id).setData(from: card, merge: true)
            } else {
                discoverCollection.document(document.id).delete { error in
                    if let error {
                        logger.error("Discover card delete failed: \(error.localizedDescription)")
                    }
                }
            }
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
                      let status = RSVPStatus(rawValue: statusStr) else { continue }

                let remoteDate = (data["respondedAt"] as? Timestamp)?.dateValue() ?? Date()
                let note = (data["note"] as? String).flatMap { $0.isEmpty ? nil : $0 }

                if let guest = event.guests.first(where: { $0.id == guestId }) {
                    // Existing guest — a newer remote response wins.
                    if let localDate = guest.respondedAt, localDate >= remoteDate { continue }
                    guest.status = status
                    guest.plusOneCount = data["partySize"] as? Int ?? guest.plusOneCount
                    guest.respondedAt = remoteDate
                    if let note {
                        if guest.metadata != nil { guest.metadata?.notes = note }
                        else { guest.metadata = GuestMetadata(notes: note) }
                    }
                    notifyHostOfRSVP(name: guest.name, status: status, event: event, remoteDate: remoteDate, into: modelContext)
                    changed = true
                } else {
                    // A response from the shareable "anyone with the link" link:
                    // no guest was pre-created for this id, so add one (keyed to
                    // the same guestId) — otherwise link RSVPs never reach the
                    // host's guest list.
                    let rawName = (data["name"] as? String)?.trimmingCharacters(in: .whitespaces)
                    let newGuest = Guest(
                        id: guestId,
                        name: (rawName?.isEmpty == false) ? rawName! : "Guest",
                        status: status,
                        plusOneCount: data["partySize"] as? Int ?? 0,
                        metadata: note.map { GuestMetadata(notes: $0) }
                    )
                    newGuest.respondedAt = remoteDate
                    event.guests.append(newGuest)
                    notifyHostOfRSVP(name: newGuest.name, status: status, event: event, remoteDate: remoteDate, into: modelContext)
                    changed = true
                }
            }
            if changed {
                modelContext.safeSave()
                logger.info("Merged guest RSVPs from the cloud.")
            }
        } catch {
            logger.error("RSVP fetch failed: \(error.localizedDescription)")
        }
    }

    /// Drops an in-app notification for the host when a guest's RSVP arrives.
    /// Recency-gated so opening an old event doesn't flood the notification
    /// center with a backlog of historical responses.
    private func notifyHostOfRSVP(name: String, status: RSVPStatus, event: Event, remoteDate: Date, into modelContext: ModelContext) {
        guard remoteDate > Date().addingTimeInterval(-7 * 86400) else { return }
        let verb: String
        switch status {
        case .attending: verb = "is going to"
        case .maybe: verb = "might attend"
        case .declined: verb = "can't make it to"
        default: verb = "responded to"
        }
        modelContext.insert(AppNotification(
            type: .rsvpUpdate,
            title: "New RSVP",
            body: "\(name) \(verb) \(event.title)",
            eventId: event.id,
            eventTitle: event.title
        ))
    }

    /// Removes a guest's cloud RSVP. Called when a host deletes a guest so an
    /// orphaned `rsvps/{guestId}` doc can't re-create that guest on the next
    /// `fetchRSVPs`. Owner-only (enforced by the security rules); fire-and-forget.
    func deleteRSVP(eventId: UUID, guestId: UUID) {
        guard Auth.auth().currentUser != nil else { return }
        eventsCollection.document(eventId.uuidString)
            .collection("rsvps").document(guestId.uuidString)
            .delete { error in
                if let error {
                    logger.error("RSVP delete failed: \(error.localizedDescription)")
                }
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
        // Already a guest of this event under a different guest id (e.g. a second
        // invite link) — don't create a duplicate entry for the same person.
        if event.guests.contains(where: { $0.userId == userId }) {
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

    /// Removes an event from Firestore, including its discovery card so it stops
    /// appearing in Explore for other users.
    func deleteEvent(id: UUID) {
        eventsCollection.document(id.uuidString).delete { error in
            if let error {
                logger.error("Event delete failed: \(error.localizedDescription)")
            }
        }
        discoverCollection.document(id.uuidString).delete { error in
            if let error {
                logger.error("Discover card delete failed: \(error.localizedDescription)")
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

    /// Reconciles the local store with the public discovery feed so `ExploreView`
    /// surfaces PUBLIC events created by OTHER users. It inserts cards the device
    /// doesn't have, refreshes ones it already materialized (so host edits show
    /// up), and prunes discovered events that dropped out of the feed (the host
    /// unpublished/deleted them or they've passed). It ONLY ever touches events
    /// flagged `isDiscovered` — a hosted or invited event is never modified or
    /// deleted. The user's own cards are skipped (already local as hosted events).
    func fetchPublicEvents(into modelContext: ModelContext) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            // Include events that started up to 24h ago so an in-progress event
            // (e.g. an all-day festival) stays discoverable and isn't pruned
            // locally while it's still happening.
            let since = Date().addingTimeInterval(-24 * 3600)
            let snapshot = try await discoverCollection
                .whereField("startDate", isGreaterThanOrEqualTo: since)
                .order(by: "startDate")
                .limit(to: 60)
                .getDocuments()
            let cards = snapshot.documents
                .compactMap { try? $0.data(as: DiscoverCard.self) }
                .filter { $0.ownerUid != uid }

            let allLocal = (try? modelContext.fetch(FetchDescriptor<Event>())) ?? []
            var localById = [UUID: Event]()
            for event in allLocal where localById[event.id] == nil { localById[event.id] = event }

            var feedIds = Set<UUID>()
            var changed = false

            for card in cards {
                guard let eventId = UUID(uuidString: card.id) else { continue }
                feedIds.insert(eventId)
                if let existing = localById[eventId] {
                    // Refresh only our own discovered copies; never a hosted or
                    // invited event that happens to share this id.
                    if existing.isDiscovered {
                        card.apply(to: existing)
                        changed = true
                    }
                } else {
                    modelContext.insert(card.makeEvent())
                    changed = true
                }
            }

            // Prune discovered events that are over, or that the feed no longer
            // lists (unpublished/deleted). Guards:
            //  - `isDiscovered`: never delete a hosted or invited event.
            //  - `guests.isEmpty`: never delete one the user has RSVP'd to — an
            //    RSVP appends a local Guest (carrying plus-ones + note that live
            //    only on-device), so pruning it would cascade-delete their RSVP.
            //    Once the user commits, the event persists like an invited one.
            // The feed is capped at 60, so a not-yet-RSVP'd discovered event
            // ranked beyond that may be pruned and re-inserted later — harmless.
            for event in allLocal
            where event.isDiscovered && event.guests.isEmpty
                && (event.isPast || !feedIds.contains(event.id)) {
                modelContext.delete(event)
                changed = true
            }

            if changed {
                modelContext.safeSave()
                logger.info("Reconciled \(feedIds.count) public event(s) from Discover.")
            }
        } catch {
            logger.error("Public event fetch failed: \(error.localizedDescription)")
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

// MARK: - Discover Card

/// A lightweight, cross-user discovery card for a PUBLIC, non-draft event. Lives
/// at the top-level `discover/{eventId}` collection so Explore can list public
/// events created by anyone, without exposing the owner-only full event doc.
/// Carries only poster-level fields — no guest list, no contact info.
struct DiscoverCard: Codable {
    var id: String
    var ownerUid: String
    var title: String
    var startDate: Date
    var endDate: Date?
    var category: String
    var city: String
    var locationName: String
    // Optional so older cards written before these fields existed still decode.
    var state: String?
    var country: String?
    var hostName: String?
    var capacity: Int?
    var attendingCount: Int
    @ServerTimestamp var updatedAt: Timestamp?

    init(event: Event, ownerUid: String, hostName: String?) {
        self.id = event.id.uuidString
        self.ownerUid = ownerUid
        self.title = event.title
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.category = event.category.rawValue
        self.city = event.location?.city ?? ""
        self.locationName = event.location?.name ?? ""
        self.state = event.location?.state
        self.country = event.location?.country
        self.hostName = hostName
        self.capacity = event.capacity
        self.attendingCount = event.attendingCount
        self.updatedAt = nil
    }

    /// Rebuilds an `EventLocation` from the card's place fields (name/city/state/
    /// country), preserving the state/country so Explore's region filters match.
    private var makeLocation: EventLocation? {
        guard !locationName.isEmpty || !city.isEmpty || !(state ?? "").isEmpty else { return nil }
        return EventLocation(
            name: locationName.isEmpty ? city : locationName,
            city: city.isEmpty ? nil : city,
            state: (state ?? "").isEmpty ? nil : state,
            country: (country ?? "").isEmpty ? nil : country
        )
    }

    /// Builds a lightweight local `Event` from this card so it shows in Explore.
    /// `hostId` is set to the OWNER's derived id (never the viewer's) so the
    /// viewer is correctly treated as a non-host and can RSVP; privacy is
    /// `.publicEvent` so `ExploreView.publicEvents` picks it up.
    func makeEvent() -> Event {
        let event = Event(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: makeLocation,
            capacity: capacity,
            privacy: .publicEvent,
            category: EventCategory(rawValue: category) ?? .custom,
            hostId: AuthManager.deterministicUUID(from: ownerUid)
        )
        event.isDiscovered = true
        event.discoveredAttendingCount = attendingCount
        return event
    }

    /// Refreshes an already-materialized discovered `Event` in place so edits the
    /// host made (title, date, place, attendance) show up on the next fetch.
    /// Only ever called for events flagged `isDiscovered`.
    func apply(to event: Event) {
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.capacity = capacity
        event.category = EventCategory(rawValue: category) ?? .custom
        event.location = makeLocation
        event.discoveredAttendingCount = attendingCount
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
