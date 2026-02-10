import Foundation
import SwiftUI
import SwiftData
import MessageUI

@MainActor
class InviteService: ObservableObject {
    static let shared = InviteService()

    @Published var isSending = false
    @Published var lastError: Error?

    private init() {}

    // MARK: - Generate Invite Link

    func generateInviteLink(guest: Guest, event: Event) -> URL? {
        // Format: gather://rsvp/{eventId}/{guestId}
        let urlString = "gather://rsvp/\(event.id.uuidString)/\(guest.id.uuidString)"
        return URL(string: urlString)
    }

    func generateShareableLink(event: Event) -> URL? {
        // Custom URL scheme — will be replaced with Universal Links when domain is configured
        let urlString = "gather://event/\(event.id.uuidString)"
        return URL(string: urlString)
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

        message += "Please RSVP in the Gather app to let us know if you can make it!\n\n"

        if let inviteLink = generateInviteLink(guest: guest, event: event) {
            message += "RSVP here: \(inviteLink.absoluteString)\n\n"
        }

        message += "Download Gather: \(AppConfig.appStoreURL.absoluteString)"

        return message
    }

    // MARK: - Send via WhatsApp

    func sendViaWhatsApp(guest: Guest, event: Event, functions: [EventFunction]) -> Bool {
        guard let phone = guest.phone?.replacingOccurrences(of: " ", with: "")
                                      .replacingOccurrences(of: "-", with: "")
                                      .replacingOccurrences(of: "(", with: "")
                                      .replacingOccurrences(of: ")", with: "") else {
            return false
        }

        let message = generateInviteMessage(guest: guest, event: event, functions: functions)
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
        guard let phone = guest.phone else { return false }

        let message = generateInviteMessage(guest: guest, event: event, functions: functions)
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "sms:\(phone)&body=\(encodedMessage)"

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

        let subject = "You're Invited to \(event.title)!"
        let body = generateInviteMessage(guest: guest, event: event, functions: functions)

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)"

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

    // MARK: - Mark Invite as Sent

    func markInviteSent(
        invite: FunctionInvite,
        channel: InviteChannel,
        modelContext: ModelContext
    ) {
        invite.inviteStatus = .sent
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

    func canSendViaWhatsApp(guest: Guest) -> Bool {
        guard let phone = guest.phone, !phone.isEmpty else { return false }
        guard let whatsappURL = URL(string: "whatsapp://") else { return false }
        return UIApplication.shared.canOpenURL(whatsappURL)
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
