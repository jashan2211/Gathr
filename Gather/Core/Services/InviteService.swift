import Foundation
import SwiftUI
import SwiftData

@MainActor
class InviteService: ObservableObject {
    static let shared = InviteService()

    @Published var isSending = false
    @Published var lastError: Error?

    private init() {}

    // MARK: - WhatsApp Availability

    /// Whether WhatsApp is installed. Requires `whatsapp` in the Info.plist
    /// `LSApplicationQueriesSchemes` array — without it `canOpenURL` always
    /// returns `false`, which is the root cause of guests with valid phone
    /// numbers being wrongly flagged as unreachable.
    var isWhatsAppInstalled: Bool {
        guard let url = URL(string: "whatsapp://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Reduces a phone number to digits plus an optional leading `+`.
    /// Formatting characters (spaces, parentheses, dashes) make `URL(string:)`
    /// fail outright for `sms:` and `whatsapp:` URLs.
    func sanitizedPhone(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        let trimmed = phone.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("+") ? "+" + digits : digits
    }

    // MARK: - Generate Invite Link

    /// Invite link — a real https URL that always resolves to the web RSVP page
    /// (`/gathr/invite`, a real file, so it can never 404). The guest can RSVP
    /// right there with no app. On iPhones with Gathr installed, iOS opens the
    /// app directly via Associated Domains instead. IDs only — no event title or
    /// guest details in the URL.
    func generateInviteLink(guest: Guest, event: Event) -> URL? {
        URL(string: "\(AppConfig.webBaseURL.absoluteString)/invite?e=\(event.id.uuidString)&g=\(guest.id.uuidString)")
    }

    func generateShareableLink(event: Event) -> URL? {
        URL(string: "\(AppConfig.webBaseURL.absoluteString)/invite?e=\(event.id.uuidString)")
    }

    /// A per-guest invite link scoped to a single function (sub-event). Same
    /// shape as the event invite plus `&f=<functionId>`, so opening it in the
    /// app routes to that function's RSVP. Each guest gets their own link.
    func generateFunctionInviteLink(guest: Guest, event: Event, function: EventFunction) -> URL? {
        URL(string: "\(AppConfig.webBaseURL.absoluteString)/invite?e=\(event.id.uuidString)&g=\(guest.id.uuidString)&f=\(function.id.uuidString)")
    }

    // MARK: - Generate Invite Message

    func generateInviteMessage(
        guest: Guest,
        event: Event,
        functions: [EventFunction]
    ) -> String {
        var message = "Hi \(guest.name.split(separator: " ").first ?? "there")!\n\n"
        message += "You're invited to \(event.title)!\n\n"

        if !functions.isEmpty {
            message += "Functions:\n"

            for function in functions.sorted(by: { $0.date < $1.date }) {
                message += "- \(function.name): \(GatherDateFormatter.fullWeekdayDateTime.string(from: function.date))"
                if let location = function.location {
                    message += " at \(location.name)"
                }
                message += "\n"
            }
            message += "\n"
        } else {
            message += "Date: \(GatherDateFormatter.fullWeekdayDateTimeYear.string(from: event.startDate))\n"

            if let location = event.location {
                message += "Location: \(location.name)\n"
            }
            message += "\n"
        }

        // One clickable link only — the universal link opens the app when
        // installed and falls back to a web page with the App Store link.
        if let inviteLink = generateInviteLink(guest: guest, event: event) {
            message += "Tap here to RSVP:\n\(inviteLink.absoluteString)"
        }

        return message
    }

    // MARK: - Generate Reminder Message

    /// Shorter, friendly nudge for guests who already received an invite.
    /// Reuses the same per-guest RSVP link so responses are still tracked.
    func generateReminderMessage(
        guest: Guest,
        event: Event,
        functions: [EventFunction]
    ) -> String {
        let firstName = guest.name.split(separator: " ").first.map(String.init) ?? "there"
        var message = "Hi \(firstName)! Just a friendly nudge about \(event.title)"

        if let nextFunction = functions.min(by: { $0.date < $1.date }) {
            message += " — \(nextFunction.name) is on \(GatherDateFormatter.fullWeekdayDateTime.string(from: nextFunction.date))"
        } else {
            message += " on \(GatherDateFormatter.fullWeekdayDateTimeYear.string(from: event.startDate))"
        }
        message += ".\n\n"
        message += "We'd love to know if you can make it!"

        if let inviteLink = generateInviteLink(guest: guest, event: event) {
            message += "\n\nRSVP here: \(inviteLink.absoluteString)"
        }

        return message
    }

    // MARK: - Generate Email Blast Body

    /// Generic (non-personalized) body for a single BCC email blast.
    /// Per-guest RSVP links can't go in one shared email, so the shareable
    /// event link is used instead.
    func generateEmailBlastBody(
        event: Event,
        functions: [EventFunction],
        isReminder: Bool = false
    ) -> String {
        var message = isReminder
            ? "Hi! Just a friendly reminder about \(event.title).\n\n"
            : "Hi!\n\nYou're invited to \(event.title)!\n\n"

        if !functions.isEmpty {
            message += "Functions:\n"
            for function in functions.sorted(by: { $0.date < $1.date }) {
                message += "- \(function.name): \(GatherDateFormatter.fullWeekdayDateTime.string(from: function.date))"
                if let location = function.location {
                    message += " at \(location.name)"
                }
                message += "\n"
            }
            message += "\n"
        } else {
            message += "Date: \(GatherDateFormatter.fullWeekdayDateTimeYear.string(from: event.startDate))\n"
            if let location = event.location {
                message += "Location: \(location.name)\n"
            }
            message += "\n"
        }

        message += isReminder
            ? "We'd love to know if you can make it!\n\n"
            : "We'd love to see you there!\n\n"

        if let shareLink = generateShareableLink(event: event) {
            message += "Tap here to RSVP:\n\(shareLink.absoluteString)"
        }

        return message
    }

    // MARK: - Send via WhatsApp

    func sendViaWhatsApp(guest: Guest, event: Event, functions: [EventFunction]) -> Bool {
        sendViaWhatsApp(
            guest: guest,
            message: generateInviteMessage(guest: guest, event: event, functions: functions)
        )
    }

    /// Opens WhatsApp with an arbitrary prefilled message (invite or reminder).
    func sendViaWhatsApp(guest: Guest, message: String) -> Bool {
        guard let rawPhone = guest.phone, !rawPhone.isEmpty else { return false }
        // WhatsApp's phone parameter expects digits only — no `+`, no spaces.
        let phone = sanitizedPhone(rawPhone).replacingOccurrences(of: "+", with: "")
        guard !phone.isEmpty else { return false }

        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "whatsapp://send?phone=\(phone)&text=\(encodedMessage)"

        guard let url = URL(string: urlString) else { return false }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return true
        }
        return false
    }

    // MARK: - Send via SMS

    func sendViaSMS(guest: Guest, event: Event, functions: [EventFunction]) -> Bool {
        sendViaSMS(
            guest: guest,
            message: generateInviteMessage(guest: guest, event: event, functions: functions)
        )
    }

    /// Opens the external Messages app via an `sms:` URL with an arbitrary
    /// body. Fallback path for devices where in-app compose is unavailable.
    func sendViaSMS(guest: Guest, message: String) -> Bool {
        guard let rawPhone = guest.phone, !rawPhone.isEmpty else { return false }
        // Strip formatting — spaces/parens/dashes make URL(string:) return nil.
        let phone = sanitizedPhone(rawPhone)
        guard !phone.isEmpty else { return false }

        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // The body must be introduced as a query ("?&body="); using "&body="
        // directly after the number makes iOS treat the whole thing as the
        // recipient and silently drop the prefilled message.
        let urlString = "sms:\(phone)?&body=\(encodedMessage)"

        guard let url = URL(string: urlString) else { return false }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return true
        }
        return false
    }

    // MARK: - Send via Email

    func sendViaEmail(guest: Guest, event: Event, functions: [EventFunction]) -> Bool {
        guard let email = guest.email else { return false }
        return sendViaEmail(
            to: [email],
            bcc: [],
            subject: "You're Invited to \(event.title)!",
            body: generateInviteMessage(guest: guest, event: event, functions: functions)
        )
    }

    /// Opens the external mail client via a `mailto:` URL. Supports BCC so
    /// the email-blast flow has a fallback when in-app mail compose is
    /// unavailable (no mail account configured).
    func sendViaEmail(to: [String], bcc: [String], subject: String, body: String) -> Bool {
        guard !to.isEmpty || !bcc.isEmpty else { return false }

        // Addresses must be percent-encoded individually: `urlQueryAllowed`
        // leaves `+ & , ; = ?` intact, so a gmail alias like "a+b@x" decodes
        // as "a b@x" and raw separators can split or inject parameters.
        var addressAllowed = CharacterSet.urlQueryAllowed
        addressAllowed.remove(charactersIn: "+&,;=?")
        func encodeAddresses(_ addresses: [String]) -> String {
            addresses
                .compactMap { $0.addingPercentEncoding(withAllowedCharacters: addressAllowed) }
                .joined(separator: ",")
        }

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        var urlString = "mailto:\(encodeAddresses(to))?subject=\(encodedSubject)&body=\(encodedBody)"
        if !bcc.isEmpty {
            urlString += "&bcc=\(encodeAddresses(bcc))"
        }

        guard let url = URL(string: urlString) else { return false }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return true
        }
        return false
    }

    // MARK: - Copy Invite Link

    func copyInviteLink(guest: Guest, event: Event) {
        if let link = generateInviteLink(guest: guest, event: event) {
            UIPasteboard.general.string = link.absoluteString
        }
    }

    // MARK: - Function Invites (per-guest, per-function)

    /// A personalized message inviting one guest to one specific function, with
    /// their own unique RSVP link.
    func generateFunctionInviteMessage(guest: Guest, event: Event, function: EventFunction) -> String {
        let firstName = guest.name.split(separator: " ").first.map(String.init) ?? "there"
        var message = "Hi \(firstName)!\n\n"
        message += "You're invited to \(function.name) — part of \(event.title).\n\n"
        message += "When: \(GatherDateFormatter.fullWeekdayDateTime.string(from: function.date))\n"
        if let location = function.location {
            message += "Where: \(location.name)\n"
        }
        if let dress = function.displayDressCode {
            message += "Dress: \(dress)\n"
        }
        message += "\n"
        if let link = generateFunctionInviteLink(guest: guest, event: event, function: function) {
            message += "Tap here to RSVP:\n\(link.absoluteString)"
        }
        return message
    }

    /// Copies a guest's unique function-invite link to the clipboard.
    func copyFunctionInviteLink(guest: Guest, event: Event, function: EventFunction) {
        if let link = generateFunctionInviteLink(guest: guest, event: event, function: function) {
            UIPasteboard.general.string = link.absoluteString
        }
    }

    /// Sends a guest their unique function invite over the chosen channel.
    /// Returns whether the send (or copy) succeeded.
    @discardableResult
    func sendFunctionInvite(guest: Guest, event: Event, function: EventFunction, via channel: InviteChannel) -> Bool {
        let message = generateFunctionInviteMessage(guest: guest, event: event, function: function)
        switch channel {
        case .whatsapp:
            return sendViaWhatsApp(guest: guest, message: message)
        case .sms:
            return sendViaSMS(guest: guest, message: message)
        case .email:
            guard let email = guest.email, !email.isEmpty else { return false }
            return sendViaEmail(to: [email], bcc: [],
                                subject: "You're invited to \(function.name)",
                                body: message)
        case .copied, .inAppLink:
            copyFunctionInviteLink(guest: guest, event: event, function: function)
            return true
        }
    }

    // MARK: - Mark Invite as Sent

    func markInviteSent(
        invite: FunctionInvite,
        channel: InviteChannel,
        modelContext: ModelContext
    ) {
        // Never downgrade a guest who already responded — resending an invite
        // records the resend (sentAt/sentVia) but keeps their .responded status,
        // which drives "has responded" checks and RSVP labels across the app.
        if invite.inviteStatus != .responded {
            invite.inviteStatus = .sent
        }
        invite.sentAt = Date()
        invite.sentVia = channel
    }

    // MARK: - Create Function Invites

    func createFunctionInvites(
        for guests: [Guest],
        functions: [EventFunction],
        modelContext: ModelContext
    ) -> [FunctionInvite] {
        var invites: [FunctionInvite] = []

        for guest in guests {
            for function in functions {
                // Check if invite already exists
                let existingInvite = function.invites.first { $0.guestId == guest.id }
                if existingInvite == nil {
                    let invite = FunctionInvite(
                        guestId: guest.id,
                        functionId: function.id
                    )
                    function.invites.append(invite)
                    invites.append(invite)
                }
            }
        }

        return invites
    }

    // MARK: - Batch Send Helpers

    /// Per-guest reachability: does the guest have a phone number? Whether
    /// WhatsApp itself is installed is a device-level check (`isWhatsAppInstalled`)
    /// — conflating the two made phone-less and WhatsApp-less indistinguishable.
    func canSendViaWhatsApp(guest: Guest) -> Bool {
        guard let phone = guest.phone, !phone.isEmpty else { return false }
        return true
    }

    func canSendViaSMS(guest: Guest) -> Bool {
        guard let phone = guest.phone, !phone.isEmpty else { return false }
        return true
    }

    func canSendViaEmail(guest: Guest) -> Bool {
        guard let email = guest.email, !email.isEmpty else { return false }
        return true
    }

    func availableChannels(for guest: Guest) -> [InviteChannel] {
        var channels: [InviteChannel] = []

        if canSendViaWhatsApp(guest: guest) {
            channels.append(.whatsapp)
        }
        if canSendViaSMS(guest: guest) {
            channels.append(.sms)
        }
        if canSendViaEmail(guest: guest) {
            channels.append(.email)
        }

        // Link copy is always available
        channels.append(.copied)

        return channels
    }
}
