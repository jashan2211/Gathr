import Foundation
import SwiftData
import os

// MARK: - Data Export Service (GDPR Compliance)

@MainActor
final class DataExportService {
    static let shared = DataExportService()
    private let logger = Logger(subsystem: "ca.thebighead.gathr", category: "DataExport")

    /// Exports all user data as a JSON file for GDPR "Right to Data Portability"
    func exportUserData(userId: UUID, userName: String, userEmail: String?, modelContext: ModelContext) throws -> URL {
        let export = UserDataExport(
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            profile: exportProfile(userId: userId, userName: userName, userEmail: userEmail),
            hostedEvents: exportHostedEvents(userId: userId, modelContext: modelContext),
            attendingEvents: exportAttendingEvents(userId: userId, modelContext: modelContext),
            tickets: exportTickets(userId: userId, userEmail: userEmail, modelContext: modelContext)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)

        let fileName = "gathr-data-export-\(formatDate(Date())).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)

        logger.info("Data export created: \(fileName) (\(data.count) bytes)")
        return tempURL
    }

    // MARK: - Private Export Helpers

    private func exportProfile(userId: UUID, userName: String, userEmail: String?) -> ProfileExport {
        ProfileExport(
            id: userId.uuidString,
            name: userName,
            email: userEmail
        )
    }

    private func exportHostedEvents(userId: UUID, modelContext: ModelContext) -> [EventExport] {
        let descriptor = FetchDescriptor<Event>()
        guard let allEvents = try? modelContext.fetch(descriptor) else { return [] }
        let events = allEvents.filter { $0.hostId == userId }

        return events.map { event in
            EventExport(
                id: event.id.uuidString,
                title: event.title,
                description: event.eventDescription,
                category: event.category.rawValue,
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location?.name,
                privacy: event.privacy.rawValue,
                createdAt: event.createdAt,
                guestCount: event.guests.count,
                functions: event.functions.map { fn in
                    FunctionExport(name: fn.name, date: fn.date, location: fn.location?.name)
                }
            )
        }
    }

    private func exportAttendingEvents(userId: UUID, modelContext: ModelContext) -> [AttendingEventExport] {
        let descriptor = FetchDescriptor<Event>()
        guard let events = try? modelContext.fetch(descriptor) else { return [] }

        var attending: [AttendingEventExport] = []
        for event in events {
            if let guest = event.guests.first(where: { $0.userId == userId }) {
                attending.append(AttendingEventExport(
                    eventTitle: event.title,
                    eventDate: event.startDate,
                    rsvpStatus: guest.status.rawValue,
                    respondedAt: guest.respondedAt
                ))
            }
        }
        return attending
    }

    private func exportTickets(userId: UUID, userEmail: String?, modelContext: ModelContext) -> [TicketExport] {
        let descriptor = FetchDescriptor<Ticket>()
        guard let tickets = try? modelContext.fetch(descriptor) else { return [] }

        return tickets.filter { ticket in
            ticket.userId == userId || (userEmail != nil && ticket.guestEmail == userEmail)
        }.map { ticket in
            TicketExport(
                ticketNumber: ticket.ticketNumber,
                eventId: ticket.eventId.uuidString,
                guestName: ticket.guestName,
                quantity: ticket.quantity,
                totalPrice: "\(ticket.totalPrice)",
                paymentStatus: ticket.paymentStatus.rawValue,
                purchasedAt: ticket.purchasedAt
            )
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Export Data Models

struct UserDataExport: Codable {
    let exportDate: Date
    let appVersion: String
    let profile: ProfileExport
    let hostedEvents: [EventExport]
    let attendingEvents: [AttendingEventExport]
    let tickets: [TicketExport]
}

struct ProfileExport: Codable {
    let id: String
    let name: String
    let email: String?
}

struct EventExport: Codable {
    let id: String
    let title: String
    let description: String?
    let category: String
    let startDate: Date
    let endDate: Date?
    let location: String?
    let privacy: String
    let createdAt: Date
    let guestCount: Int
    let functions: [FunctionExport]
}

struct FunctionExport: Codable {
    let name: String
    let date: Date
    let location: String?
}

struct AttendingEventExport: Codable {
    let eventTitle: String
    let eventDate: Date
    let rsvpStatus: String
    let respondedAt: Date?
}

struct TicketExport: Codable {
    let ticketNumber: String
    let eventId: String
    let guestName: String
    let quantity: Int
    let totalPrice: String
    let paymentStatus: String
    let purchasedAt: Date
}
