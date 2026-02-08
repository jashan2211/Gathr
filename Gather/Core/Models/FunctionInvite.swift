import Foundation
import SwiftData

// MARK: - Function Invite Model

@Model
final class FunctionInvite {
    var id: UUID
    var guestId: UUID
    var functionId: UUID

    // Status tracking
    var inviteStatus: InviteStatus
    var sentAt: Date?
    var sentVia: InviteChannel?

    // Response
    var response: RSVPResponse?
    var partySize: Int
    var notes: String?
    var respondedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        guestId: UUID,
        functionId: UUID,
        inviteStatus: InviteStatus = .notSent,
        sentAt: Date? = nil,
        sentVia: InviteChannel? = nil,
        response: RSVPResponse? = nil,
        partySize: Int = 1,
        notes: String? = nil,
        respondedAt: Date? = nil
    ) {
        self.id = id
        self.guestId = guestId
        self.functionId = functionId
        self.inviteStatus = inviteStatus
        self.sentAt = sentAt
        self.sentVia = sentVia
        self.response = response
        self.partySize = partySize
        self.notes = notes
        self.respondedAt = respondedAt
        self.createdAt = Date()
    }
}

// MARK: - Invite Status

enum InviteStatus: String, Codable, CaseIterable {
    case notSent
    case sent
    case responded

    var displayName: String {
        switch self {
        case .notSent: return "Not Sent"
        case .sent: return "Sent"
        case .responded: return "Responded"
        }
    }

    var icon: String {
        switch self {
        case .notSent: return "envelope"
        case .sent: return "paperplane.fill"
        case .responded: return "checkmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .notSent: return "gray"
        case .sent: return "blue"
        case .responded: return "green"
        }
    }
}

// MARK: - RSVP Response

enum RSVPResponse: String, Codable, CaseIterable {
    case yes
    case no
    case maybe

    var displayName: String {
        switch self {
        case .yes: return "Yes"
        case .no: return "No"
        case .maybe: return "Maybe"
        }
    }

    var icon: String {
        switch self {
        case .yes: return "checkmark.circle.fill"
        case .no: return "xmark.circle.fill"
        case .maybe: return "questionmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .yes: return "green"
        case .no: return "red"
        case .maybe: return "orange"
        }
    }
}

// MARK: - Invite Channel

enum InviteChannel: String, Codable, CaseIterable {
    case whatsapp
    case sms
    case email
    case inAppLink
    case copied

    var displayName: String {
        switch self {
        case .whatsapp: return "WhatsApp"
        case .sms: return "SMS"
        case .email: return "Email"
        case .inAppLink: return "In-App Link"
        case .copied: return "Link Copied"
        }
    }

    var icon: String {
        switch self {
        case .whatsapp: return "message.fill"
        case .sms: return "bubble.left.fill"
        case .email: return "envelope.fill"
        case .inAppLink: return "link"
        case .copied: return "doc.on.doc.fill"
        }
    }

    var color: String {
        switch self {
        case .whatsapp: return "green"
        case .sms: return "blue"
        case .email: return "purple"
        case .inAppLink: return "orange"
        case .copied: return "gray"
        }
    }
}

// MARK: - Function Invite Helpers

extension FunctionInvite {
    var hasResponded: Bool {
        inviteStatus == .responded && response != nil
    }

    var isAttending: Bool {
        response == .yes
    }

    var statusSummary: String {
        switch inviteStatus {
        case .notSent:
            return "Not invited yet"
        case .sent:
            return "Awaiting response"
        case .responded:
            if let response = response {
                switch response {
                case .yes:
                    return partySize > 1 ? "Coming (\(partySize) guests)" : "Coming"
                case .no:
                    return "Not coming"
                case .maybe:
                    return "Maybe"
                }
            }
            return "Responded"
        }
    }
}
