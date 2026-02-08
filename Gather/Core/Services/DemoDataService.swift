import Foundation
import SwiftData

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

        try? modelContext.save()
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
            print("Error resetting data: \(error)")
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

        try? modelContext.save()
    }

    // MARK: - Random Event Generator

    private func generateRandomEvent(index: Int, hostId: UUID) -> Event {
        let category = massiveCategories.randomElement()!
        let location = massiveLocations.randomElement()!
        let template = massiveTemplates[category]!.randomElement()!
        let isHosted = index % 4 == 0 // 25% hosted by user
        let isPublic = !isHosted && index % 3 == 0 // ~25% public
        let dayOffset = Double(Int.random(in: 2...120))
        let durationHours = Double([2, 3, 4, 5, 6, 8, 12].randomElement()!)
        let guestCount = Int.random(in: 4...40)
        let capacity = guestCount + Int.random(in: 5...60)

        let event = Event(
            title: template.title,
            eventDescription: template.desc,
            startDate: Date().addingTimeInterval(86400 * dayOffset),
            endDate: Date().addingTimeInterval(86400 * dayOffset + 3600 * durationHours),
            location: EventLocation(
                name: location.venue,
                address: location.address,
                city: location.city,
                state: location.state,
                country: location.country,
                latitude: location.lat,
                longitude: location.lon
            ),
            capacity: capacity,
            privacy: isPublic ? .publicEvent : .inviteOnly,
            category: category,
            enabledFeatures: randomFeatures(for: category),
            hostId: isHosted ? hostId : UUID(),
            isDraft: isHosted && index % 12 == 0
        )

        // Add guests
        let names = massiveGuestNames.shuffled().prefix(guestCount)
        let statuses: [RSVPStatus] = [.attending, .attending, .attending, .maybe, .declined, .pending]
        for (gi, name) in names.enumerated() {
            let status = statuses.randomElement()!
            let plusOnes = status == .attending && gi % 5 == 0 ? Int.random(in: 1...3) : 0
            let guest = Guest(name: name, status: status, plusOneCount: plusOnes)
            if status != .pending {
                guest.respondedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400*20))
            }
            // Some party members
            if plusOnes > 0 {
                guest.partyMembers = (0..<plusOnes).map { pi in
                    PartyMember(name: "Guest of \(name.components(separatedBy: " ").first ?? name) \(pi + 1)", relationship: pi == 0 ? .partner : .other)
                }
            }
            event.guests.append(guest)
        }

        // If user is attending (not hosted), add user guest
        if !isHosted && index % 5 == 0 {
            let userGuest = Guest(name: "You", email: "you@email.com", status: .attending, userId: hostId)
            event.guests.append(userGuest)
        }

        // Maybe add functions
        if category != .meetup && Bool.random() {
            let functionNames = massiveFunctionNames[category] ?? ["Session 1", "Session 2"]
            let funcs = functionNames.prefix(Int.random(in: 1...min(3, functionNames.count)))
            var timeOffset: Double = 0
            for fname in funcs {
                let f = EventFunction(
                    name: fname,
                    functionDescription: "Part of \(template.title)",
                    date: Date().addingTimeInterval(86400 * dayOffset + timeOffset),
                    endTime: Date().addingTimeInterval(86400 * dayOffset + timeOffset + 5400),
                    location: EventLocation(name: location.venue),
                    dressCode: [DressCode.casual, .smartCasual, .cocktail, .formal].randomElement()!,
                    eventId: event.id
                )
                event.functions.append(f)
                timeOffset += 5400
            }
        }

        // Maybe add ticketing for public events
        if isPublic && Bool.random() {
            let prices: [Decimal] = [0, 10, 15, 20, 25, 35, 50]
            let ga = TicketTier(name: "General Admission", price: prices.randomElement()!, capacity: capacity - 20, eventId: event.id)
            ga.soldCount = Int.random(in: 10...max(11, capacity / 2))
            event.ticketTiers = [ga]
            if Bool.random() {
                let vip = TicketTier(name: "VIP", price: prices.randomElement()! + 20, capacity: 20, eventId: event.id)
                vip.soldCount = Int.random(in: 0...15)
                event.ticketTiers.append(vip)
            }
        }

        return event
    }

    private func generateRandomBudget(for event: Event, modelContext: ModelContext) {
        let total = Double([500, 800, 1000, 1500, 2000, 3000, 5000].randomElement()!)
        let budget = Budget(eventId: event.id, totalBudget: total)

        let catNames = ["Venue", "Food", "Drinks", "Decorations", "Entertainment", "Supplies", "Transport"]
        let catIcons = ["building.2", "fork.knife", "cup.and.saucer", "sparkles", "music.note", "bag", "car"]
        let catColors = ["purple", "pink", "blue", "yellow", "orange", "green", "secondary"]
        let numCats = Int.random(in: 2...5)
        let perCat = total / Double(numCats)

        for ci in 0..<numCats {
            let cat = BudgetCategory(
                name: catNames[ci],
                icon: catIcons[ci],
                allocated: perCat,
                color: catColors[ci],
                sortOrder: ci
            )
            cat.spent = Double.random(in: 0...perCat)

            // Add 1-3 expenses per category
            let demoPayerNames = ["You", "Alex", "Sam", "Jordan", "Taylor"]
            for ei in 0..<Int.random(in: 1...3) {
                let amt = Double.random(in: 20...perCat * 0.6)
                let paid = Bool.random()
                let expense = Expense(
                    name: "\(catNames[ci]) item \(ei + 1)",
                    amount: amt,
                    isPaid: paid,
                    paidDate: paid ? Date().addingTimeInterval(-Double.random(in: 86400...86400*14)) : nil,
                    dueDate: !paid ? Date().addingTimeInterval(Double.random(in: 86400...86400*30)) : nil,
                    vendorName: Bool.random() ? "Vendor \(ci + 1)" : nil,
                    paidByName: paid ? demoPayerNames.randomElement() : nil,
                    functionId: nil
                )
                cat.expenses.append(expense)
            }

            budget.categories.append(cat)
        }

        modelContext.insert(budget)
    }

    private func randomFeatures(for category: EventCategory) -> Set<EventFeature> {
        var features: Set<EventFeature> = [.guestManagement]
        if Bool.random() { features.insert(.activity) }
        if Bool.random() { features.insert(.photos) }
        if [.wedding, .party, .conference].contains(category) && Bool.random() { features.insert(.functions) }
        if [.wedding, .party, .conference, .concert].contains(category) && Bool.random() { features.insert(.budget) }
        return features
    }

    // MARK: - Data Pools

    private var massiveCategories: [EventCategory] {
        [.party, .party, .meetup, .meetup, .conference, .concert, .wedding, .office, .custom]
    }

    private struct LocationData {
        let venue: String; let address: String; let city: String; let state: String; let country: String; let lat: Double; let lon: Double
    }

    private var massiveLocations: [LocationData] {
        [
            LocationData(venue: "The Grand Ballroom", address: "100 Main St", city: "Los Angeles", state: "CA", country: "USA", lat: 34.05, lon: -118.25),
            LocationData(venue: "Rooftop 21", address: "21 Market St", city: "San Francisco", state: "CA", country: "USA", lat: 37.78, lon: -122.42),
            LocationData(venue: "Brooklyn Bowl", address: "61 Wythe Ave", city: "New York", state: "NY", country: "USA", lat: 40.72, lon: -73.96),
            LocationData(venue: "The Rustic", address: "3656 Howell St", city: "Dallas", state: "TX", country: "USA", lat: 32.79, lon: -96.80),
            LocationData(venue: "Warehouse District Loft", address: "710 N 2nd Ave", city: "Minneapolis", state: "MN", country: "USA", lat: 44.98, lon: -93.26),
            LocationData(venue: "Bayfront Park", address: "301 Biscayne Blvd", city: "Miami", state: "FL", country: "USA", lat: 25.77, lon: -80.19),
            LocationData(venue: "Fremont Studios", address: "155 N 35th St", city: "Seattle", state: "WA", country: "USA", lat: 47.65, lon: -122.35),
            LocationData(venue: "The Fillmore", address: "1805 Geary Blvd", city: "San Francisco", state: "CA", country: "USA", lat: 37.78, lon: -122.43),
            LocationData(venue: "Music Box", address: "1148 N Western Ave", city: "Chicago", state: "IL", country: "USA", lat: 41.90, lon: -87.69),
            LocationData(venue: "Stubb's BBQ", address: "801 Red River St", city: "Austin", state: "TX", country: "USA", lat: 30.27, lon: -97.74),
            LocationData(venue: "Pearl District Gallery", address: "100 NW Glisan St", city: "Portland", state: "OR", country: "USA", lat: 45.53, lon: -122.67),
            LocationData(venue: "Red Rocks Amphitheatre", address: "18300 W Alameda Pkwy", city: "Denver", state: "CO", country: "USA", lat: 39.67, lon: -105.21),
            LocationData(venue: "Ponce City Market", address: "675 Ponce De Leon Ave", city: "Atlanta", state: "GA", country: "USA", lat: 33.77, lon: -84.36),
            LocationData(venue: "The Belmont", address: "305 W 6th St", city: "Austin", state: "TX", country: "USA", lat: 30.27, lon: -97.75),
            LocationData(venue: "Neon Museum", address: "770 Las Vegas Blvd N", city: "Las Vegas", state: "NV", country: "USA", lat: 36.18, lon: -115.14),
            LocationData(venue: "Hana Hou", address: "1 Aloha Tower Dr", city: "Honolulu", state: "HI", country: "USA", lat: 21.31, lon: -157.87),
            LocationData(venue: "Innovation Hub", address: "50 Milk St", city: "Boston", state: "MA", country: "USA", lat: 42.36, lon: -71.06),
            LocationData(venue: "The Paramount", address: "713 Congress Ave", city: "Austin", state: "TX", country: "USA", lat: 30.27, lon: -97.74),
            LocationData(venue: "Liberty Station", address: "2640 Historic Decatur Rd", city: "San Diego", state: "CA", country: "USA", lat: 32.74, lon: -117.21),
            LocationData(venue: "Armature Works", address: "1910 N Ola Ave", city: "Tampa", state: "FL", country: "USA", lat: 27.96, lon: -82.46),
        ]
    }

    private struct EventTemplate {
        let title: String; let desc: String
    }

    private var massiveTemplates: [EventCategory: [EventTemplate]] {
        [
            .party: [
                EventTemplate(title: "Neon Glow Party", desc: "UV paint, glow sticks, and blacklights. Wear white!"),
                EventTemplate(title: "Rooftop Sunset Party", desc: "Golden hour cocktails and city skyline views."),
                EventTemplate(title: "90s Throwback Night", desc: "Dust off your bucket hats and platform shoes. TLC on repeat."),
                EventTemplate(title: "Brunch & Bubbles", desc: "Bottomless mimosas, build-your-own waffle bar, and vibes."),
                EventTemplate(title: "Full Moon Party", desc: "Dance under the moonlight with fire dancers and drum circles."),
                EventTemplate(title: "Taco Tuesday Fiesta", desc: "All-you-can-eat tacos, margarita bar, and a pi\u{00F1}ata."),
                EventTemplate(title: "Halloween Costume Bash", desc: "Best costume wins a mystery prize. Haunted cocktails."),
                EventTemplate(title: "Pool Party Splash", desc: "Floaties required. DJ by the pool. Bring sunscreen."),
                EventTemplate(title: "Karaoke Night", desc: "Private rooms, endless songs, zero judgment. Let's go!"),
                EventTemplate(title: "New Year's Eve Countdown", desc: "Ring in the new year with champagne, confetti, and friends."),
            ],
            .meetup: [
                EventTemplate(title: "Coffee & Code", desc: "Bring your laptop, grab a coffee, work alongside other devs."),
                EventTemplate(title: "Book Club: Monthly Read", desc: "This month's pick just dropped. Grab it and join the discussion."),
                EventTemplate(title: "Dog Park Hangout", desc: "Let the pups play while we chat. All breeds welcome!"),
                EventTemplate(title: "Hiking Crew: Trail Day", desc: "Moderate 5-mile loop with amazing views. Beginners welcome."),
                EventTemplate(title: "Photography Walk", desc: "Golden hour shoot through the city. All camera types welcome."),
                EventTemplate(title: "Pottery Workshop", desc: "Get your hands dirty! Instructor-led wheel throwing class."),
                EventTemplate(title: "Running Club: 5K", desc: "Casual 5K run followed by smoothies. All paces welcome."),
                EventTemplate(title: "Language Exchange", desc: "Practice a new language over coffee. 20+ languages represented."),
                EventTemplate(title: "Board Game Meetup", desc: "Dozens of games to choose from. Snacks provided."),
                EventTemplate(title: "Volunteer Day: Beach Cleanup", desc: "Help keep our beaches clean! Gloves and bags provided."),
            ],
            .conference: [
                EventTemplate(title: "AI & The Future Summit", desc: "Industry leaders discuss what's next for artificial intelligence."),
                EventTemplate(title: "Founders Meetup", desc: "Pitch practice, networking, and real talk about startup life."),
                EventTemplate(title: "Design Systems Conference", desc: "Deep dives into scalable design. Figma, tokens, and more."),
                EventTemplate(title: "DevOps Day", desc: "CI/CD pipelines, Kubernetes, and infrastructure as code."),
                EventTemplate(title: "Product Management Forum", desc: "Roadmaps, prioritization, and stakeholder management."),
                EventTemplate(title: "Women in Tech Summit", desc: "Panels, workshops, and networking for women in technology."),
                EventTemplate(title: "Climate Tech Expo", desc: "Startups building the future of sustainability."),
                EventTemplate(title: "Blockchain & Beyond", desc: "Beyond the hype: real use cases for distributed systems."),
            ],
            .concert: [
                EventTemplate(title: "Jazz Under the Stars", desc: "Live jazz trio, wine bar, and twinkling lights."),
                EventTemplate(title: "Indie Rock Showcase", desc: "4 local bands, one stage, all killer no filler."),
                EventTemplate(title: "Electronic Music Night", desc: "Deep house to techno. Quality sound system. BYOB."),
                EventTemplate(title: "Acoustic Sessions", desc: "Intimate singer-songwriter performances by candlelight."),
                EventTemplate(title: "Hip Hop Open Mic", desc: "Bring your bars! Freestyle and written welcome."),
                EventTemplate(title: "Latin Music Festival", desc: "Salsa, reggaeton, cumbia - dance all night long!"),
                EventTemplate(title: "Vinyl Listening Party", desc: "Full album playback on premium speakers. Chill vibes."),
                EventTemplate(title: "Battle of the Bands", desc: "Local bands compete for a recording studio prize package."),
            ],
            .wedding: [
                EventTemplate(title: "Emma & Liam's Wedding", desc: "Garden ceremony followed by dinner and dancing."),
                EventTemplate(title: "Sophia & James' Big Day", desc: "Beachside ceremony at sunset. Reception under the tent."),
                EventTemplate(title: "Mia & Noah's Celebration", desc: "Intimate vineyard wedding with farm-to-table dinner."),
                EventTemplate(title: "Ava & Ethan Say I Do", desc: "Rooftop ceremony downtown. Cocktail hour, then party!"),
            ],
            .office: [
                EventTemplate(title: "Q1 Team Offsite", desc: "Strategy planning, team building, and an escape room challenge."),
                EventTemplate(title: "Company All-Hands", desc: "Quarterly updates from leadership. Q&A. Free lunch."),
                EventTemplate(title: "New Hire Welcome Mixer", desc: "Meet the latest additions to the team. Casual and fun."),
                EventTemplate(title: "Lunch & Learn: AI Tools", desc: "Hands-on workshop with the latest AI productivity tools."),
                EventTemplate(title: "End of Year Party", desc: "Celebrate wins, share memories, and look ahead to next year."),
            ],
            .custom: [
                EventTemplate(title: "Flea Market & Vintage Fair", desc: "Vintage clothes, handmade crafts, and one-of-a-kind finds."),
                EventTemplate(title: "Film Screening: Short Films", desc: "Curated selection of indie short films. Popcorn included."),
                EventTemplate(title: "Plant Swap", desc: "Bring a plant, take a plant. Succulent workshop included."),
                EventTemplate(title: "Garage Sale Crawl", desc: "Map of 15+ garage sales in the neighborhood. Treasures await."),
            ],
        ]
    }

    private var massiveGuestNames: [String] {
        [
            "Aaliyah Brooks", "Amir Shah", "Ana Gutierrez", "Andre Baptiste", "Aria Patel",
            "Bianca Torres", "Blake Morrison", "Bodhi Pham", "Brooklyn Davis", "Cameron Reyes",
            "Carlos Mendoza", "Carmen Silva", "Cassidy Burke", "Chloe Park", "Chris Yamamoto",
            "Coral Adams", "Dahlia Shah", "Dani Okoye", "Dante Cruz", "Dex Washington",
            "Diego Morales", "Elena Popov", "Eli Moreau", "Ember Jones", "Eva Lindgren",
            "Fatima Hassan", "Felix Herrera", "Finn O'Brien", "Freya Larson", "Grace Kim",
            "Hana Park", "Harper Quinn", "Imani Lewis", "Iris Chang", "Isaiah Cole",
            "Jade Thompson", "Jae Kim", "Jamal Wright", "Jasper Roy", "Jay Chakrabarti",
            "Jesse Okafor", "Jordan Rivera", "Jules Fontaine", "Jun Park", "Kai Lim",
            "Kira Novak", "Kofi Mensah", "Lara Costa", "Leo Nakamura", "Liam O'Sullivan",
            "Lily Nakamura", "Luna Reyes", "Malia Kealoha", "Marco Liu", "Maya Santos",
            "Mei Lin", "Mika Tanaka", "Mira Patel", "Nadia Al-Rashid", "Nate Kumar",
            "Nia Jackson", "Nina Volkov", "Noah Gutierrez", "Nora Jensen", "Ola Adeyemi",
            "Omar Farah", "Oscar Reyes", "Petra Novak", "Priya Kapoor", "Quinn Murphy",
            "Raj Mehta", "Raven Cole", "Rex Moreno", "Rio Santos", "Rosa Martinez",
            "Ruby Alvarez", "Sage Williams", "Sam Oduya", "Sasha Petrov", "Sienna Patel",
            "Sky Martinez", "Sol Garcia", "Tao Chen", "Toni Reed", "Tyler Brooks",
            "Wei Zhang", "Wren Taylor", "Yara Salim", "Yuki Sato", "Zara Ibrahim",
            "Zola Asante", "Zuri Williams", "River Kim", "Phoenix Lee", "Nova Gray",
            "Aiden Cross", "Sable Monroe", "Cruz Delgado", "Indigo Wolfe", "Remy Laurent",
        ]
    }

    private var massiveFunctionNames: [EventCategory: [String]] {
        [
            .party: ["Welcome Drinks", "Main Event", "After Party", "Late Night Bites"],
            .wedding: ["Ceremony", "Cocktail Hour", "Reception", "First Dance", "After Party"],
            .conference: ["Keynote", "Panel Discussion", "Workshop", "Networking Hour", "Closing Remarks"],
            .concert: ["Opening Act", "Main Performance", "Encore", "VIP Meet & Greet"],
            .office: ["Presentations", "Team Activity", "Lunch Break", "Awards Ceremony"],
            .custom: ["Part 1", "Part 2", "Wrap Up"],
        ]
    }

    // MARK: - Hosted Event 1: Maya's 25th Birthday Bash

    private func createBirthdayBash(hostId: UUID, modelContext: ModelContext) -> Event {
        let event = Event(
            title: "Maya's 25th Birthday Bash",
            eventDescription: "It's my quarter-life crisis party and you're invited! Rooftop vibes, good music, even better people. Dress to impress \u{2728}",
            startDate: Date().addingTimeInterval(86400 * 14),
            endDate: Date().addingTimeInterval(86400 * 14 + 21600),
            location: EventLocation(
                name: "Skyline Rooftop Bar",
                address: "550 S Flower St, Downtown LA",
                city: "Los Angeles",
                state: "CA",
                country: "USA",
                latitude: 34.0490,
                longitude: -118.2572
            ),
            capacity: 30,
            privacy: .inviteOnly,
            category: .party,
            enabledFeatures: [.functions, .guestManagement, .budget, .activity, .photos],
            hostId: hostId
        )

        // Functions
        let preGame = EventFunction(
            name: "Pre-game Drinks",
            functionDescription: "Casual drinks at the bar downstairs before we head up to the rooftop",
            date: Date().addingTimeInterval(86400 * 14),
            endTime: Date().addingTimeInterval(86400 * 14 + 5400),
            location: EventLocation(name: "Lobby Bar"),
            dressCode: .casual,
            eventId: event.id
        )

        let mainParty = EventFunction(
            name: "Main Party",
            functionDescription: "Rooftop takeover! DJ, photo booth, and birthday cake at midnight",
            date: Date().addingTimeInterval(86400 * 14 + 5400),
            endTime: Date().addingTimeInterval(86400 * 14 + 18000),
            location: EventLocation(name: "Skyline Rooftop"),
            dressCode: .cocktail,
            eventId: event.id
        )

        let lateNight = EventFunction(
            name: "Late Night Tacos",
            functionDescription: "Taco truck parked outside for the real ones who stay late",
            date: Date().addingTimeInterval(86400 * 14 + 18000),
            endTime: Date().addingTimeInterval(86400 * 14 + 21600),
            location: EventLocation(name: "Street Level"),
            dressCode: .casual,
            eventId: event.id
        )

        event.functions = [preGame, mainParty, lateNight]

        // Add guests
        let birthdayGuests: [(String, String?, RSVPStatus, GuestRole, Int)] = [
            ("Aisha Chen", "aisha.c@gmail.com", .attending, .cohost, 0),
            ("Jordan Rivera", "j.rivera@email.com", .attending, .vip, 1),
            ("Priya Kapoor", "priya.k@email.com", .attending, .guest, 0),
            ("Marcus Thompson", "marc.t@email.com", .attending, .guest, 2),
            ("Lily Nakamura", "lily.n@email.com", .attending, .guest, 0),
            ("Dev Patel", "dev.p@email.com", .maybe, .guest, 0),
            ("Sasha Okonkwo", "sasha.o@email.com", .attending, .guest, 1),
            ("Tyler Brooks", "tyler.b@email.com", .attending, .guest, 0),
            ("Zara Kim", "zara.k@email.com", .attending, .guest, 0),
            ("Noah Gutierrez", "noah.g@email.com", .declined, .guest, 0),
            ("Fatima Hassan", "fatima.h@email.com", .attending, .guest, 1),
            ("Chris Matsuda", nil, .pending, .guest, 0),
            ("Aaliyah Johnson", "aaliyah.j@email.com", .maybe, .guest, 0),
            ("Raj Mehta", nil, .pending, .guest, 0),
            ("Bianca Lopez", "bianca.l@email.com", .attending, .guest, 0),
            ("Sam Oduya", "sam.o@email.com", .attending, .guest, 1),
            ("Nina Volkov", nil, .pending, .guest, 0),
            ("Dante Williams", "dante.w@email.com", .maybe, .guest, 0),
            ("Hana Park", "hana.p@email.com", .attending, .guest, 0),
            ("Eli Moreau", "eli.m@email.com", .pending, .guest, 0),
        ]

        for (name, email, status, role, plusOnes) in birthdayGuests {
            let guest = Guest(
                name: name,
                email: email,
                status: status,
                plusOneCount: plusOnes,
                role: role
            )
            if status != .pending {
                guest.respondedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400*10))
            }

            // Party members for some guests
            if name == "Marcus Thompson" {
                guest.partyMembers = [
                    PartyMember(name: "Keisha Thompson", relationship: .partner),
                    PartyMember(name: "DJ Thompson", relationship: .other)
                ]
            } else if name == "Sasha Okonkwo" {
                guest.partyMembers = [
                    PartyMember(name: "Tunde Okonkwo", relationship: .partner)
                ]
            } else if name == "Fatima Hassan" {
                guest.partyMembers = [
                    PartyMember(name: "Layla Hassan", relationship: .other)
                ]
            } else if name == "Sam Oduya" {
                guest.partyMembers = [
                    PartyMember(name: "Ade Oduya", relationship: .other)
                ]
            }

            event.guests.append(guest)

            // Function invites
            for function in event.functions {
                let invite = FunctionInvite(guestId: guest.id, functionId: function.id)
                let rand = Int.random(in: 0...10)
                if rand < 5 {
                    invite.inviteStatus = .responded
                    invite.response = status == .attending ? .yes : (status == .maybe ? .maybe : .no)
                    invite.partySize = invite.response == .yes ? (1 + plusOnes) : 0
                    invite.respondedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400*7))
                } else if rand < 8 {
                    invite.inviteStatus = .sent
                    invite.sentAt = Date().addingTimeInterval(-Double.random(in: 86400...86400*10))
                    invite.sentVia = [.whatsapp, .email, .sms].randomElement()
                }
                function.invites.append(invite)
            }
        }

        // Budget
        createBudgetForEvent(
            event: event,
            total: 3000,
            categoryData: [
                ("Venue", "building.2", "purple", 800, 800, true, "Skyline Rooftop"),
                ("Food & Drinks", "fork.knife", "pink", 1200, 450, false, "Lucky's Catering"),
                ("DJ", "music.note", "orange", 500, 500, true, "DJ Spinz"),
                ("Decorations", "sparkles", "yellow", 300, 180, true, "Party City"),
                ("Photo Booth", "camera", "blue", 200, 0, false, "SnapShot Co")
            ],
            expenses: [
                ("Rooftop deposit", 400, true, "Skyline Rooftop", 0, -14, "You"),
                ("Rooftop balance", 400, true, "Skyline Rooftop", 0, -3, "You"),
                ("Appetizer trays x5", 250, true, "Lucky's Catering", 1, -7, "Jordan Rivera"),
                ("Open bar (3hr)", 200, false, "Lucky's Catering", 1, 10, nil),
                ("DJ booking fee", 500, true, "DJ Spinz", 2, -10, "Aisha Chen"),
                ("Balloon arch", 120, true, "Party City", 3, -5, "You"),
                ("Table centerpieces", 60, true, "Party City", 3, -5, "Aisha Chen"),
            ],
            splits: [
                ("Aisha Chen", "aisha.c@gmail.com", 750, 750),
                ("Jordan Rivera", "j.rivera@email.com", 500, 300)
            ],
            modelContext: modelContext
        )

        return event
    }

    // MARK: - Hosted Event 2: Friday Game Night

    private func createGameNight(hostId: UUID) -> Event {
        let event = Event(
            title: "Friday Game Night",
            eventDescription: "Board games, card games, and snacks. BYOB! Currently obsessed with Wingspan and Codenames. Bring your competitive spirit.",
            startDate: Date().addingTimeInterval(86400 * 5),
            endDate: Date().addingTimeInterval(86400 * 5 + 14400),
            location: EventLocation(
                name: "Jake's Apartment",
                address: "2847 Hyperion Ave, Silver Lake",
                city: "Los Angeles",
                state: "CA",
                country: "USA"
            ),
            capacity: 12,
            privacy: .inviteOnly,
            category: .meetup,
            enabledFeatures: [.guestManagement, .activity],
            hostId: hostId
        )

        let gameGuests: [(String, RSVPStatus)] = [
            ("Mika Tanaka", .attending),
            ("Oscar Reyes", .attending),
            ("Chloe Park", .attending),
            ("Amit Sharma", .attending),
            ("Ruby Chen", .attending),
            ("Dex Washington", .maybe),
            ("Juno Kwon", .attending),
            ("Felix Osei", .attending),
            ("Ava Nguyen", .declined),
            ("Isaiah Cole", .attending),
        ]

        for (name, status) in gameGuests {
            let guest = Guest(name: name, status: status)
            if status != .pending {
                guest.respondedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400*5))
            }
            event.guests.append(guest)
        }

        return event
    }

    // MARK: - Hosted Event 3: Friendsgiving 2026

    private func createFriendsgiving(hostId: UUID, modelContext: ModelContext) -> Event {
        let event = Event(
            title: "Friendsgiving 2026",
            eventDescription: "Our annual Friendsgiving! Potluck style - sign up for what you're bringing. Kids welcome, dogs tolerated \u{1F436}",
            startDate: Date().addingTimeInterval(86400 * 30),
            endDate: Date().addingTimeInterval(86400 * 30 + 28800),
            location: EventLocation(
                name: "The House on Maple St",
                address: "421 Maple St, Pasadena, CA",
                city: "Pasadena",
                state: "CA",
                country: "USA",
                latitude: 34.1478,
                longitude: -118.1445
            ),
            capacity: 25,
            privacy: .inviteOnly,
            category: .party,
            enabledFeatures: [.functions, .guestManagement, .budget, .activity, .photos],
            hostId: hostId
        )

        // Functions
        let cooking = EventFunction(
            name: "Cooking Session",
            functionDescription: "Help prep the turkey and sides! Many hands make light work",
            date: Date().addingTimeInterval(86400 * 30),
            endTime: Date().addingTimeInterval(86400 * 30 + 10800),
            location: EventLocation(name: "Kitchen"),
            dressCode: .casual,
            eventId: event.id
        )

        let dinner = EventFunction(
            name: "Dinner",
            functionDescription: "The main event! Turkey, sides, and going around the table saying what we're thankful for",
            date: Date().addingTimeInterval(86400 * 30 + 14400),
            endTime: Date().addingTimeInterval(86400 * 30 + 21600),
            location: EventLocation(name: "Dining Room"),
            dressCode: .casual,
            eventId: event.id
        )

        let games = EventFunction(
            name: "Board Games",
            functionDescription: "Post-dinner games and pie. Settlers of Catan tournament!",
            date: Date().addingTimeInterval(86400 * 30 + 21600),
            endTime: Date().addingTimeInterval(86400 * 30 + 28800),
            location: EventLocation(name: "Living Room"),
            dressCode: .casual,
            eventId: event.id
        )

        event.functions = [cooking, dinner, games]

        // Guests with families
        let fgGuests: [(String, String?, RSVPStatus, Int)] = [
            ("Elena Rodriguez", "elena.r@email.com", .attending, 2),
            ("Kevin O'Brien", "kevin.ob@email.com", .attending, 1),
            ("Nadia Al-Rashid", "nadia.r@email.com", .attending, 3),
            ("Jake Chen", "jake.c@email.com", .attending, 0),
            ("Simone Dubois", "simone.d@email.com", .maybe, 1),
            ("Tommy Tran", "tommy.t@email.com", .attending, 0),
            ("Ola Adeyemi", "ola.a@email.com", .attending, 2),
            ("Grace Kim", "grace.k@email.com", .attending, 0),
            ("Mateo Sandoval", nil, .pending, 0),
            ("Iris Chang", "iris.c@email.com", .attending, 0),
            ("Andre Baptiste", nil, .pending, 0),
            ("Yuki Sato", "yuki.s@email.com", .attending, 1),
            ("Lamar Jackson", "lamar.j@email.com", .declined, 0),
            ("Petra Novak", "petra.n@email.com", .maybe, 0),
            ("Dom Rossi", "dom.r@email.com", .attending, 0),
            ("Asha Patel", nil, .pending, 0),
            ("Kai Lim", "kai.l@email.com", .attending, 1),
            ("Brooklyn Davis", "brooklyn.d@email.com", .attending, 0),
        ]

        for (name, email, status, plusOnes) in fgGuests {
            let guest = Guest(name: name, email: email, status: status, plusOneCount: plusOnes)
            if status != .pending {
                guest.respondedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400*14))
            }

            // Families
            if name == "Elena Rodriguez" {
                guest.partyMembers = [
                    PartyMember(name: "Carlos Rodriguez", relationship: .spouse),
                    PartyMember(name: "Sofia Rodriguez", relationship: .child)
                ]
            } else if name == "Nadia Al-Rashid" {
                guest.partyMembers = [
                    PartyMember(name: "Omar Al-Rashid", relationship: .spouse),
                    PartyMember(name: "Leila Al-Rashid", relationship: .child),
                    PartyMember(name: "Adam Al-Rashid", relationship: .child, dietaryRestrictions: "No dairy")
                ]
            } else if name == "Ola Adeyemi" {
                guest.partyMembers = [
                    PartyMember(name: "Tayo Adeyemi", relationship: .partner),
                    PartyMember(name: "Zuri Adeyemi", relationship: .child)
                ]
            }

            event.guests.append(guest)

            for function in event.functions {
                let invite = FunctionInvite(guestId: guest.id, functionId: function.id)
                let rand = Int.random(in: 0...10)
                if rand < 5 {
                    invite.inviteStatus = .responded
                    invite.response = status == .attending ? .yes : (status == .maybe ? .maybe : .no)
                    invite.partySize = invite.response == .yes ? (1 + plusOnes) : 0
                    invite.respondedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400*7))
                } else if rand < 8 {
                    invite.inviteStatus = .sent
                    invite.sentAt = Date().addingTimeInterval(-Double.random(in: 86400...86400*10))
                    invite.sentVia = [.whatsapp, .email, .sms].randomElement()
                }
                function.invites.append(invite)
            }
        }

        // Budget
        createBudgetForEvent(
            event: event,
            total: 800,
            categoryData: [
                ("Turkey & Mains", "fork.knife", "pink", 250, 180, false, nil),
                ("Sides & Desserts", "birthday.cake", "orange", 200, 85, false, nil),
                ("Drinks", "cup.and.saucer", "blue", 150, 120, true, "Costco"),
                ("Decorations", "sparkles", "yellow", 100, 45, false, nil),
                ("Misc", "ellipsis.circle", "secondary", 100, 30, false, nil)
            ],
            expenses: [
                ("20lb turkey", 65, true, "Costco", 0, -7, "You"),
                ("Ham", 45, false, nil, 0, 5, nil),
                ("Mashed potatoes supplies", 70, true, "Trader Joe's", 0, -3, "Kevin O'Brien"),
                ("Pie ingredients", 35, true, "Whole Foods", 1, -4, "Grace Kim"),
                ("Mac & cheese (3 trays)", 50, false, nil, 1, 3, nil),
                ("Wine (6 bottles)", 80, true, "Costco", 2, -5, "Kevin O'Brien"),
                ("Craft beer (2 cases)", 40, true, "Costco", 2, -5, "Jake Chen"),
                ("Fall leaf garland", 25, true, "Target", 3, -6, "You"),
                ("Candles", 20, true, "Target", 3, -6, "You"),
                ("Paper plates/cups", 30, false, nil, 4, 2, nil),
            ],
            splits: [
                ("Kevin O'Brien", "kevin.ob@email.com", 200, 200),
                ("Jake Chen", "jake.c@email.com", 200, 100),
                ("Grace Kim", "grace.k@email.com", 150, 0)
            ],
            modelContext: modelContext
        )

        return event
    }

    // MARK: - Hosted Event 4: Summer Road Trip (Draft)

    private func createRoadTrip(hostId: UUID, modelContext: ModelContext) -> Event {
        let event = Event(
            title: "Summer Road Trip",
            eventDescription: "LA \u{2192} Joshua Tree \u{2192} Sedona \u{2192} Grand Canyon \u{2192} Vegas. 5 days, 1 van, infinite memories. Still planning!",
            startDate: Date().addingTimeInterval(86400 * 90),
            endDate: Date().addingTimeInterval(86400 * 95),
            location: EventLocation(
                name: "Multi-stop Road Trip",
                address: "Starting from Los Angeles",
                city: "Los Angeles",
                state: "CA",
                country: "USA"
            ),
            capacity: 8,
            privacy: .inviteOnly,
            category: .custom,
            enabledFeatures: [.guestManagement, .budget, .activity],
            hostId: hostId,
            isDraft: true
        )

        let tripGuests: [(String, RSVPStatus)] = [
            ("Mika Tanaka", .attending),
            ("Oscar Reyes", .attending),
            ("Chloe Park", .maybe),
            ("Tyler Brooks", .attending),
            ("Ruby Chen", .attending),
            ("Dex Washington", .pending),
        ]

        for (name, status) in tripGuests {
            let guest = Guest(name: name, status: status)
            if status != .pending {
                guest.respondedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400*5))
            }
            event.guests.append(guest)
        }

        // Budget
        createBudgetForEvent(
            event: event,
            total: 2000,
            categoryData: [
                ("Gas", "fuelpump", "orange", 500, 0, false, nil),
                ("Airbnb", "house", "purple", 800, 0, false, nil),
                ("Food", "fork.knife", "pink", 400, 0, false, nil),
                ("Activities", "figure.hiking", "green", 300, 0, false, nil)
            ],
            expenses: [],
            splits: [],
            modelContext: modelContext
        )

        return event
    }

    // MARK: - Attending Event 1: Engagement Party

    private func createEngagementParty(currentUserId: UUID) -> Event {
        let otherHostId = UUID()

        let event = Event(
            title: "Zoe & Kai's Engagement Party",
            eventDescription: "She said yes! Join us for cocktails and celebration at the vineyard. It's going to be magical.",
            startDate: Date().addingTimeInterval(86400 * 21),
            endDate: Date().addingTimeInterval(86400 * 21 + 18000),
            location: EventLocation(
                name: "Malibu Wine Vineyard",
                address: "31740 Mulholland Hwy, Malibu, CA",
                city: "Malibu",
                state: "CA",
                country: "USA",
                latitude: 34.1067,
                longitude: -118.7548
            ),
            capacity: 80,
            privacy: .inviteOnly,
            category: .party,
            enabledFeatures: [.functions, .guestManagement, .activity, .photos],
            hostId: otherHostId
        )

        // User attending with +1
        let currentUserGuest = Guest(
            name: "You",
            email: "you@email.com",
            status: .attending,
            plusOneCount: 1,
            userId: currentUserId
        )
        currentUserGuest.partyMembers = [
            PartyMember(name: "Your Partner", relationship: .partner)
        ]
        event.guests.append(currentUserGuest)

        let cocktails = EventFunction(
            name: "Cocktails & Mingling",
            functionDescription: "Welcome cocktails on the terrace overlooking the vineyard",
            date: Date().addingTimeInterval(86400 * 21),
            endTime: Date().addingTimeInterval(86400 * 21 + 7200),
            location: EventLocation(name: "Terrace"),
            dressCode: .cocktail,
            eventId: event.id
        )
        let dinnerToast = EventFunction(
            name: "Dinner & Toasts",
            functionDescription: "Sit-down dinner with heartfelt toasts from friends and family",
            date: Date().addingTimeInterval(86400 * 21 + 7200),
            endTime: Date().addingTimeInterval(86400 * 21 + 18000),
            location: EventLocation(name: "The Barrel Room"),
            dressCode: .cocktail,
            eventId: event.id
        )
        event.functions = [cocktails, dinnerToast]

        return event
    }

    // MARK: - Attending Event 2: Startup Demo Day

    private func createDemoDay(currentUserId: UUID) -> Event {
        let otherHostId = UUID()

        let event = Event(
            title: "Startup Demo Day",
            eventDescription: "10 startups, 5 minutes each. Networking, free food, and maybe your next big opportunity.",
            startDate: Date().addingTimeInterval(86400 * 10),
            endDate: Date().addingTimeInterval(86400 * 10 + 14400),
            location: EventLocation(
                name: "TechHub Downtown",
                address: "600 Wilshire Blvd, Los Angeles, CA",
                city: "Los Angeles",
                state: "CA",
                country: "USA",
                latitude: 34.0511,
                longitude: -118.2578
            ),
            capacity: 200,
            privacy: .publicEvent,
            category: .conference,
            enabledFeatures: [.ticketing, .schedule, .activity],
            hostId: otherHostId
        )

        let currentUserGuest = Guest(
            name: "You",
            email: "you@email.com",
            status: .attending,
            plusOneCount: 0,
            userId: currentUserId
        )
        event.guests.append(currentUserGuest)

        // Ticket tiers
        let free = TicketTier(name: "General Admission", price: 0, capacity: 150, eventId: event.id)
        free.soldCount = 89
        let vip = TicketTier(name: "VIP (Front Row + Lunch)", price: 25, capacity: 50, eventId: event.id)
        vip.soldCount = 31
        event.ticketTiers = [free, vip]

        return event
    }

    // MARK: - Attending Event 3: Beach Bonfire Night

    private func createBeachBonfire(currentUserId: UUID) -> Event {
        let otherHostId = UUID()

        let event = Event(
            title: "Beach Bonfire Night",
            eventDescription: "S'mores, guitars, and good vibes under the stars. Bring a blanket and a friend!",
            startDate: Date().addingTimeInterval(86400 * 8),
            endDate: Date().addingTimeInterval(86400 * 8 + 18000),
            location: EventLocation(
                name: "El Matador Beach",
                address: "32215 Pacific Coast Hwy, Malibu, CA",
                city: "Malibu",
                state: "CA",
                country: "USA",
                latitude: 34.0381,
                longitude: -118.8744
            ),
            capacity: 40,
            privacy: .inviteOnly,
            category: .meetup,
            enabledFeatures: [.guestManagement, .activity, .photos],
            hostId: otherHostId
        )

        let currentUserGuest = Guest(
            name: "You",
            email: "you@email.com",
            status: .attending,
            plusOneCount: 2,
            userId: currentUserId
        )
        currentUserGuest.partyMembers = [
            PartyMember(name: "Alex", relationship: .other),
            PartyMember(name: "Jamie", relationship: .other)
        ]
        event.guests.append(currentUserGuest)

        return event
    }

    // MARK: - Public Event 1: Downtown Art Walk

    private func createArtWalk() -> Event {
        let otherHostId = UUID()
        let event = Event(
            title: "Downtown Art Walk",
            eventDescription: "Explore 20+ galleries, live muralists, street performers, and pop-up shops. Free entry, pay-what-you-wish for drinks.",
            startDate: Date().addingTimeInterval(86400 * 12),
            endDate: Date().addingTimeInterval(86400 * 12 + 14400),
            location: EventLocation(
                name: "Arts District",
                address: "300 S Santa Fe Ave",
                city: "Los Angeles",
                state: "CA",
                country: "USA",
                latitude: 34.0375,
                longitude: -118.2340
            ),
            capacity: 500,
            privacy: .publicEvent,
            category: .meetup,
            enabledFeatures: [.guestManagement, .activity, .photos],
            hostId: otherHostId
        )

        let artGuests: [(String, RSVPStatus)] = [
            ("Nina Santos", .attending), ("Kai Matsuda", .attending),
            ("Raven Cole", .attending), ("Omar Farah", .attending),
            ("Lena Cho", .attending), ("Diego Morales", .attending),
            ("Zuri Williams", .attending), ("Sasha Petrov", .maybe),
            ("Amir Hassan", .attending), ("Bella Torres", .attending),
            ("Jae Kim", .attending), ("Toni Reed", .attending),
            ("Mira Patel", .attending), ("Jesse Okafor", .maybe),
            ("Yara Salim", .attending),
        ]
        for (name, status) in artGuests {
            let guest = Guest(name: name, status: status)
            guest.respondedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400*8))
            event.guests.append(guest)
        }
        return event
    }

    // MARK: - Public Event 2: Street Food Festival

    private func createFoodFestival() -> Event {
        let otherHostId = UUID()
        let event = Event(
            title: "SF Street Food Festival",
            eventDescription: "50+ food trucks, live DJ, beer garden, and a dumpling eating contest. Come hungry, leave happy.",
            startDate: Date().addingTimeInterval(86400 * 18),
            endDate: Date().addingTimeInterval(86400 * 18 + 28800),
            location: EventLocation(
                name: "Civic Center Plaza",
                address: "1 Dr Carlton B Goodlett Pl",
                city: "San Francisco",
                state: "CA",
                country: "USA",
                latitude: 37.7793,
                longitude: -122.4193
            ),
            capacity: 1000,
            privacy: .publicEvent,
            category: .party,
            enabledFeatures: [.ticketing, .activity, .photos],
            hostId: otherHostId
        )

        // Ticket tiers
        let ga = TicketTier(name: "General Admission", price: 10, capacity: 800, eventId: event.id)
        ga.soldCount = 342
        let vip = TicketTier(name: "VIP (Skip the Line + Drink Tokens)", price: 35, capacity: 200, eventId: event.id)
        vip.soldCount = 87
        event.ticketTiers = [ga, vip]

        let foodGuests: [(String, RSVPStatus)] = [
            ("Marco Liu", .attending), ("Priya Desai", .attending),
            ("Tomoko Sato", .attending), ("Anya Reeves", .attending),
            ("Carlos Vega", .attending), ("Jade Thompson", .attending),
            ("Leo Nakamura", .attending), ("Sofia Ruiz", .attending),
            ("Dani Okoye", .attending), ("Max Chen", .attending),
            ("Ruby Alvarez", .attending), ("Nate Kumar", .maybe),
        ]
        for (name, status) in foodGuests {
            let guest = Guest(name: name, status: status)
            guest.respondedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400*12))
            event.guests.append(guest)
        }
        return event
    }

    // MARK: - Public Event 3: Open Mic Night

    private func createOpenMicNight() -> Event {
        let otherHostId = UUID()
        let event = Event(
            title: "Open Mic Night: Poets & Comics",
            eventDescription: "5 minutes of fame! Sign up to perform poetry, comedy, or music. Hosted by local legend Drea Moon. Two-drink minimum.",
            startDate: Date().addingTimeInterval(86400 * 6),
            endDate: Date().addingTimeInterval(86400 * 6 + 10800),
            location: EventLocation(
                name: "The Velvet Lounge",
                address: "412 Broadway",
                city: "New York",
                state: "NY",
                country: "USA",
                latitude: 40.7193,
                longitude: -73.9987
            ),
            capacity: 80,
            privacy: .publicEvent,
            category: .concert,
            enabledFeatures: [.guestManagement, .activity],
            hostId: otherHostId
        )

        let micGuests: [(String, RSVPStatus)] = [
            ("Drea Moon", .attending), ("Jamal Wright", .attending),
            ("Sienna Patel", .attending), ("Tao Chen", .attending),
            ("Mika Olsen", .maybe), ("Rio Santos", .attending),
            ("Cleo Baptiste", .attending), ("Ash Kapoor", .attending),
            ("Zane Mitchell", .attending), ("Isa Moreno", .attending),
        ]
        for (name, status) in micGuests {
            let guest = Guest(name: name, status: status)
            guest.respondedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400*5))
            event.guests.append(guest)
        }
        return event
    }

    // MARK: - Public Event 4: Yoga in the Park

    private func createYogaInThePark() -> Event {
        let otherHostId = UUID()
        let event = Event(
            title: "Sunrise Yoga in the Park",
            eventDescription: "Start your Saturday with a 90-minute vinyasa flow overlooking the lake. All levels welcome. Bring your own mat!",
            startDate: Date().addingTimeInterval(86400 * 9),
            endDate: Date().addingTimeInterval(86400 * 9 + 5400),
            location: EventLocation(
                name: "Zilker Park",
                address: "2100 Barton Springs Rd",
                city: "Austin",
                state: "TX",
                country: "USA",
                latitude: 30.2669,
                longitude: -97.7729
            ),
            capacity: 100,
            privacy: .publicEvent,
            category: .meetup,
            enabledFeatures: [.guestManagement, .activity, .photos],
            hostId: otherHostId
        )

        let yogaGuests: [(String, RSVPStatus)] = [
            ("Luna Reyes", .attending), ("Bodhi Pham", .attending),
            ("Sage Williams", .attending), ("Kira Novak", .attending),
            ("Amara Obi", .attending), ("River Kim", .attending),
            ("Ivy Chen", .attending), ("Sol Garcia", .maybe),
            ("Wren Taylor", .attending), ("Dahlia Shah", .attending),
            ("Finn O'Brien", .attending), ("Coral Adams", .attending),
            ("Sky Martinez", .attending), ("Ember Jones", .attending),
        ]
        for (name, status) in yogaGuests {
            let guest = Guest(name: name, status: status)
            guest.respondedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400*7))
            event.guests.append(guest)
        }
        return event
    }

    // MARK: - Public Event 5: Vinyl Swap Meet

    private func createVinylSwapMeet() -> Event {
        let otherHostId = UUID()
        let event = Event(
            title: "Vinyl Swap Meet & DJ Sets",
            eventDescription: "Bring your records to trade! 30+ vendors, rare finds, live DJ sets all day. Crate diggers paradise.",
            startDate: Date().addingTimeInterval(86400 * 15),
            endDate: Date().addingTimeInterval(86400 * 15 + 21600),
            location: EventLocation(
                name: "Wynwood Marketplace",
                address: "2250 NW 2nd Ave",
                city: "Miami",
                state: "FL",
                country: "USA",
                latitude: 25.8015,
                longitude: -80.1994
            ),
            capacity: 200,
            privacy: .publicEvent,
            category: .concert,
            enabledFeatures: [.ticketing, .activity, .photos],
            hostId: otherHostId
        )

        let free = TicketTier(name: "Free Entry", price: 0, capacity: 150, eventId: event.id)
        free.soldCount = 63
        let earlyBird = TicketTier(name: "Early Bird (9am Access)", price: 15, capacity: 50, eventId: event.id)
        earlyBird.soldCount = 41
        event.ticketTiers = [free, earlyBird]

        let vinylGuests: [(String, RSVPStatus)] = [
            ("DJ Rhythmo", .attending), ("Kenji Flores", .attending),
            ("Aaliyah Brown", .attending), ("Mateo Ruiz", .attending),
            ("Nia Jackson", .attending), ("Felix Herrera", .attending),
            ("Simone Blanc", .attending), ("Dante Cruz", .maybe),
            ("Lyla Kofi", .attending), ("Rex Moreno", .attending),
            ("Zola Asante", .attending),
        ]
        for (name, status) in vinylGuests {
            let guest = Guest(name: name, status: status)
            guest.respondedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400*10))
            event.guests.append(guest)
        }
        return event
    }

    // MARK: - Public Event 6: Hackathon

    private func createHackathon() -> Event {
        let otherHostId = UUID()
        let event = Event(
            title: "Build Day: 24hr Hackathon",
            eventDescription: "Form a team, pick a challenge, build something amazing in 24 hours. Prizes for top 3 teams. Food and caffeine provided.",
            startDate: Date().addingTimeInterval(86400 * 22),
            endDate: Date().addingTimeInterval(86400 * 23),
            location: EventLocation(
                name: "The Garage",
                address: "525 Portage Ave",
                city: "Chicago",
                state: "IL",
                country: "USA",
                latitude: 41.8819,
                longitude: -87.6278
            ),
            capacity: 120,
            privacy: .publicEvent,
            category: .conference,
            enabledFeatures: [.ticketing, .guestManagement, .schedule, .activity],
            hostId: otherHostId
        )

        let hackerFree = TicketTier(name: "Hacker (Free)", price: 0, capacity: 100, eventId: event.id)
        hackerFree.soldCount = 54
        let mentor = TicketTier(name: "Mentor Pass", price: 0, capacity: 20, eventId: event.id)
        mentor.soldCount = 12
        event.ticketTiers = [hackerFree, mentor]

        let hackGuests: [(String, RSVPStatus)] = [
            ("Wei Zhang", .attending), ("Aria Patel", .attending),
            ("Kofi Mensah", .attending), ("Elena Popov", .attending),
            ("Jun Park", .attending), ("Zara Ibrahim", .attending),
            ("Liam O'Sullivan", .attending), ("Mei Lin", .attending),
            ("Yusuf Ali", .attending), ("Rosa Martinez", .attending),
            ("Andre Baptiste", .maybe), ("Nora Jensen", .attending),
            ("Ravi Sharma", .attending),
        ]
        for (name, status) in hackGuests {
            let guest = Guest(name: name, status: status)
            guest.respondedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400*15))
            event.guests.append(guest)
        }
        return event
    }

    // MARK: - Budget Helper

    private func createBudgetForEvent(
        event: Event,
        total: Double,
        categoryData: [(String, String, String, Double, Double, Bool, String?)],
        expenses: [(String, Double, Bool, String?, Int, Int, String?)],
        splits: [(String, String?, Double, Double)],
        modelContext: ModelContext
    ) {
        let budget = Budget(eventId: event.id, totalBudget: total)

        // Create categories
        var categories: [BudgetCategory] = []
        for (index, data) in categoryData.enumerated() {
            let (name, icon, color, allocated, spent, _, _) = data
            let category = BudgetCategory(
                name: name,
                icon: icon,
                allocated: allocated,
                color: color,
                sortOrder: index
            )
            category.spent = spent
            categories.append(category)
            budget.categories.append(category)
        }

        // Create expenses
        for expenseData in expenses {
            let (name, amount, isPaid, vendor, categoryIndex, dayOffset, paidBy) = expenseData

            let dueDate: Date? = !isPaid ? Date().addingTimeInterval(Double(dayOffset) * 86400) : nil
            let paidDate: Date? = isPaid ? Date().addingTimeInterval(Double(dayOffset) * 86400) : nil

            let expense = Expense(
                name: name,
                amount: amount,
                isPaid: isPaid,
                paidDate: paidDate,
                dueDate: dueDate,
                vendorName: vendor,
                paidByName: paidBy,
                functionId: nil
            )

            if categoryIndex < categories.count {
                categories[categoryIndex].expenses.append(expense)
            }
        }

        // Create splits
        for splitData in splits {
            let (name, email, shareAmount, paidAmount) = splitData
            let split = PaymentSplit(
                name: name,
                email: email,
                shareAmount: shareAmount,
                paidAmount: paidAmount
            )
            budget.splits.append(split)
        }

        modelContext.insert(budget)
    }

    // MARK: - Demo Team Members

    private func addDemoTeamMembers(for event: Event, modelContext: ModelContext) {
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

    private func addDemoNotifications(birthday: Event, friendsgiving: Event, modelContext: ModelContext) {
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

    private func addActivityPosts(to event: Event, hostId: UUID, modelContext: ModelContext) {
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
