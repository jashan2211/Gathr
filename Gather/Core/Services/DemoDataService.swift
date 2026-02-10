import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "ca.thebighead.gathr", category: "DemoDataService")

// MARK: - Demo Data Service

@MainActor
class DemoDataService {
    static let shared = DemoDataService()

    private init() {}

    // MARK: - Load Demo Data

    func loadDemoData(modelContext: ModelContext, hostId: UUID) {
        // Create demo events the user is HOSTING
        let birthday = createBirthdayBash(hostId: hostId, modelContext: modelContext)
        let gameNight = createGameNight(hostId: hostId)
        let friendsgiving = createFriendsgiving(hostId: hostId, modelContext: modelContext)
        let roadTrip = createRoadTrip(hostId: hostId, modelContext: modelContext)

        modelContext.insert(birthday)
        modelContext.insert(gameNight)
        modelContext.insert(friendsgiving)
        modelContext.insert(roadTrip)

        // Create events the user is ATTENDING (for Going tab)
        let engagement = createEngagementParty(currentUserId: hostId)
        let demoDay = createDemoDay(currentUserId: hostId)
        let bonfire = createBeachBonfire(currentUserId: hostId)

        modelContext.insert(engagement)
        modelContext.insert(demoDay)
        modelContext.insert(bonfire)

        // Create PUBLIC events for Explore tab (various cities)
        let artWalk = createArtWalk()
        let foodFest = createFoodFestival()
        let openMic = createOpenMicNight()
        let yogaFest = createYogaInThePark()
        let vinylMarket = createVinylSwapMeet()
        let hackathon = createHackathon()

        modelContext.insert(artWalk)
        modelContext.insert(foodFest)
        modelContext.insert(openMic)
        modelContext.insert(yogaFest)
        modelContext.insert(vinylMarket)
        modelContext.insert(hackathon)

        // Add activity posts to hosted events
        addActivityPosts(to: birthday, hostId: hostId, modelContext: modelContext)
        addActivityPosts(to: friendsgiving, hostId: hostId, modelContext: modelContext)

        // Add demo team members
        addDemoTeamMembers(for: birthday, modelContext: modelContext)
        addDemoTeamMembers(for: friendsgiving, modelContext: modelContext)

        // Add demo notifications
        addDemoNotifications(birthday: birthday, friendsgiving: friendsgiving, modelContext: modelContext)

        modelContext.safeSave()
    }

    // MARK: - Reset Demo Data

    func resetAllData(modelContext: ModelContext) {
        do {
            try modelContext.delete(model: Event.self)
            try modelContext.delete(model: Guest.self)
            try modelContext.delete(model: EventFunction.self)
            try modelContext.delete(model: FunctionInvite.self)
            try modelContext.delete(model: ActivityPost.self)
            try modelContext.delete(model: MediaItem.self)
            try modelContext.delete(model: TicketTier.self)
            try modelContext.delete(model: Ticket.self)
            try modelContext.delete(model: PromoCode.self)
            try modelContext.delete(model: PartyMember.self)
            try modelContext.delete(model: WaitlistEntry.self)
            try modelContext.delete(model: Budget.self)
            try modelContext.delete(model: BudgetCategory.self)
            try modelContext.delete(model: Expense.self)
            try modelContext.delete(model: PaymentSplit.self)
            try modelContext.delete(model: EventMember.self)
            try modelContext.delete(model: AppNotification.self)
            try modelContext.save()
        } catch {
            logger.error("Error resetting data: \(error.localizedDescription)")
        }
    }

    // MARK: - Load Massive Data (Stress Test)

    func loadMassiveData(modelContext: ModelContext, hostId: UUID, eventCount: Int) {
        // First load the curated demo data
        loadDemoData(modelContext: modelContext, hostId: hostId)

        // Then generate procedural events
        let extraCount = max(0, eventCount - 13) // 13 curated events already loaded
        for i in 0..<extraCount {
            let event = generateRandomEvent(index: i, hostId: hostId)
            modelContext.insert(event)

            // 30% chance of budget for hosted events
            if event.hostId == hostId && Bool.random() && Bool.random() == false {
                generateRandomBudget(for: event, modelContext: modelContext)
            }
        }

        modelContext.safeSave()
    }
}
