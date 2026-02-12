import Foundation
import SwiftData

@Model
final class SeatingTable {
    var id: UUID
    var name: String
    var capacity: Int
    var guestIds: [UUID]
    var eventId: UUID

    init(
        id: UUID = UUID(),
        name: String,
        capacity: Int = 8,
        guestIds: [UUID] = [],
        eventId: UUID
    ) {
        self.id = id
        self.name = name
        self.capacity = capacity
        self.guestIds = guestIds
        self.eventId = eventId
    }

    var remainingSeats: Int {
        capacity - guestIds.count
    }

    var isFull: Bool {
        guestIds.count >= capacity
    }
}
