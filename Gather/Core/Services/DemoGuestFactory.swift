import Foundation
import SwiftData

// MARK: - Demo Guest Factory
// Contains guest/invite/activity generation helpers for demo data

extension DemoDataService {

    // MARK: - Demo Team Members

    func addDemoTeamMembers(for event: Event, modelContext: ModelContext) {
        let teamData: [(String, String?, EventRole, MemberInviteStatus)] = [
            ("Aisha Chen", "aisha.c@gmail.com", .admin, .accepted),
            ("Jordan Rivera", "j.rivera@email.com", .manager, .accepted),
            ("Dev Patel", "dev.p@email.com", .viewer, .pending),
        ]

        for (name, email, role, status) in teamData {
            let member = EventMember(
                eventId: event.id,
                name: name,
                email: email,
                role: role,
                inviteStatus: status
            )
            if status == .accepted {
                member.respondedAt = Date().addingTimeInterval(-Double.random(in: 86400...86400*7))
            }
            modelContext.insert(member)
        }
    }

    // MARK: - Demo Notifications

    func addDemoNotifications(birthday: Event, friendsgiving: Event, modelContext: ModelContext) {
        let notifications: [(NotificationType, String, String, UUID?, String?, Bool, TimeInterval)] = [
            (.rsvpUpdate, "RSVP Received", "Fatima Hassan confirmed she's attending with +1", birthday.id, birthday.title, false, -300),
            (.rsvpUpdate, "New RSVP", "Sam Oduya is attending your event", birthday.id, birthday.title, false, -1800),
            (.memberJoined, "Team Member Joined", "Aisha Chen accepted the Admin invite", birthday.id, birthday.title, false, -3600),
            (.paymentDue, "Payment Due Soon", "Open bar payment of $200 due in 10 days", birthday.id, birthday.title, false, -7200),
            (.expenseAdded, "Expense Added", "Jordan added \"Appetizer trays\" ($250) to Food & Drinks", birthday.id, birthday.title, true, -14400),
            (.budgetAlert, "Budget Alert", "Food & Drinks category is approaching its limit", birthday.id, birthday.title, true, -28800),
            (.rsvpUpdate, "RSVP Update", "Elena Rodriguez confirmed for Friendsgiving with family of 3", friendsgiving.id, friendsgiving.title, true, -43200),
            (.guestAdded, "Guest Added", "You added 3 new guests to Friendsgiving", friendsgiving.id, friendsgiving.title, true, -86400),
            (.paymentReceived, "Payment Received", "Kevin O'Brien paid their share ($200)", friendsgiving.id, friendsgiving.title, true, -172800),
            (.eventReminder, "Event Reminder", "Friday Game Night is in 5 days!", nil, nil, true, -259200),
            (.memberInvite, "Invite Sent", "Dev Patel has been invited as Viewer", birthday.id, birthday.title, true, -345600),
        ]

        for (type, title, body, eventId, eventTitle, isRead, offset) in notifications {
            let notification = AppNotification(
                type: type,
                title: title,
                body: body,
                eventId: eventId,
                eventTitle: eventTitle,
                isRead: isRead
            )
            notification.createdAt = Date().addingTimeInterval(offset)
            modelContext.insert(notification)
        }
    }

    // MARK: - Activity Posts

    func addActivityPosts(to event: Event, hostId: UUID, modelContext: ModelContext) {
        let announcement = ActivityPost(
            text: "So excited for this! Please RSVP soon so we can finalize the headcount. Can't wait to see everyone!",
            postType: .announcement,
            isPinned: true,
            authorId: hostId,
            authorName: "Host",
            isHostPost: true,
            eventId: event.id
        )
        announcement.likes = 8
        modelContext.insert(announcement)

        let question = ActivityPost(
            text: "Is there parking nearby? I'm driving from the valley.",
            postType: .question,
            authorId: UUID(),
            authorName: "Priya Kapoor",
            isHostPost: false,
            eventId: event.id
        )
        question.likes = 3
        modelContext.insert(question)

        let answer = ActivityPost(
            text: "Yes! Street parking is free after 6pm and there's a garage half a block away ($10 flat rate).",
            postType: .answer,
            parentPostId: question.id,
            authorId: hostId,
            authorName: "Host",
            isHostPost: true,
            eventId: event.id
        )
        modelContext.insert(answer)

        let poll = ActivityPost(
            text: "What should the birthday cake flavor be?",
            postType: .poll,
            pollOptions: [
                PollOption(text: "Chocolate Fudge", voteCount: 7, voterIds: (0..<7).map { _ in UUID() }),
                PollOption(text: "Tres Leches", voteCount: 9, voterIds: (0..<9).map { _ in UUID() }),
                PollOption(text: "Red Velvet", voteCount: 4, voterIds: (0..<4).map { _ in UUID() }),
                PollOption(text: "Matcha", voteCount: 3, voterIds: (0..<3).map { _ in UUID() })
            ],
            authorId: hostId,
            authorName: "Host",
            isHostPost: true,
            eventId: event.id
        )
        poll.likes = 12
        modelContext.insert(poll)

        let update = ActivityPost(
            text: "Sasha Okonkwo just RSVPed with +1! \u{1F389}",
            postType: .update,
            authorId: nil,
            authorName: "Gather",
            isHostPost: false,
            eventId: event.id
        )
        modelContext.insert(update)
    }
}
