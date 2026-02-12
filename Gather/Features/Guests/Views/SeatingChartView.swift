import SwiftUI
import SwiftData

struct SeatingChartView: View {
    @Bindable var event: Event
    @Environment(\.modelContext) private var modelContext
    @Query private var tables: [SeatingTable]
    @State private var showAddTable = false
    @State private var selectedTable: SeatingTable?
    @State private var showAssignGuests = false

    init(event: Event) {
        self.event = event
        let eventId = event.id
        _tables = Query(
            filter: #Predicate<SeatingTable> { $0.eventId == eventId },
            sort: \SeatingTable.name
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    seatingStats
                    if tables.isEmpty {
                        emptyState
                    } else {
                        tablesGrid
                    }
                    unassignedGuestsSection
                }
                .padding()
            }
            .navigationTitle("Seating Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddTable = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddTable) {
                AddTableSheet(eventId: event.id)
            }
            .sheet(isPresented: $showAssignGuests) {
                if let table = selectedTable {
                    AssignGuestsSheet(event: event, table: table)
                }
            }
        }
    }

    // MARK: - Seating Stats

    private var seatingStats: some View {
        HStack(spacing: Spacing.lg) {
            StatCard(title: "Tables", value: "\(tables.count)", icon: "tablecells")
            StatCard(title: "Seated", value: "\(seatedCount)", icon: "person.fill.checkmark")
            StatCard(title: "Unassigned", value: "\(unassignedGuests.count)", icon: "person.fill.questionmark")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "tablecells")
                .font(.system(size: 50))
                .foregroundStyle(Color.accentPurpleFallback)

            Text("No Tables Yet")
                .font(GatherFont.headline)

            Text("Create tables to assign guests for seating")
                .font(GatherFont.body)
                .foregroundStyle(Color.gatherSecondaryText)
                .multilineTextAlignment(.center)

            Button {
                showAddTable = true
            } label: {
                Text("Add First Table")
                    .font(GatherFont.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Tables Grid

    private var tablesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
            ForEach(tables) { table in
                TableCard(table: table) {
                    selectedTable = table
                    showAssignGuests = true
                } onDelete: {
                    modelContext.delete(table)
                    modelContext.safeSave()
                }
            }
        }
    }

    // MARK: - Unassigned Guests

    private var unassignedGuests: [Guest] {
        let assignedIds = Set(tables.flatMap { $0.guestIds })
        return event.guests.filter { !assignedIds.contains($0.id) }
    }

    private var seatedCount: Int {
        tables.reduce(0) { $0 + $1.guestIds.count }
    }

    private var unassignedGuestsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Unassigned Guests")
                    .font(GatherFont.headline)
                Spacer()
                Text("\(unassignedGuests.count)")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(Capsule())
            }

            if unassignedGuests.isEmpty {
                Text("All guests have been assigned to tables!")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSuccess)
                    .padding()
            } else {
                ForEach(unassignedGuests) { guest in
                    HStack {
                        Circle()
                            .fill(Color.gatherSecondaryBackground)
                            .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                            .overlay {
                                Text(guest.name.prefix(1))
                                    .font(GatherFont.caption)
                            }
                        Text(guest.name)
                            .font(GatherFont.body)
                        if guest.plusOneCount > 0 {
                            Text("+\(guest.plusOneCount)")
                                .font(GatherFont.caption)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                        Spacer()
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentPurpleFallback)
            Text(value)
                .font(GatherFont.title2)
                .fontWeight(.bold)
            Text(title)
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gatherSecondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

struct TableCard: View {
    let table: SeatingTable
    let onAssign: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.accentPurpleFallback.opacity(0.1))
                    .frame(width: 60, height: 60)
                Image(systemName: "tablecells")
                    .font(.title)
                    .foregroundStyle(Color.accentPurpleFallback)
            }

            Text(table.name)
                .font(GatherFont.headline)

            Text("\(table.guestIds.count)/\(table.capacity) seats")
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gatherSecondaryBackground)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(table.isFull ? Color.gatherSuccess : Color.accentPurpleFallback)
                        .frame(
                            width: geometry.size.width * CGFloat(table.guestIds.count) / CGFloat(max(table.capacity, 1)),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
            .padding(.horizontal)

            HStack(spacing: Spacing.sm) {
                Button {
                    onAssign()
                } label: {
                    Text("Assign")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.accentPurpleFallback)
                }
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(Color.gatherError)
                }
            }
        }
        .padding()
        .background(Color.gatherSecondaryBackground.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
    }
}

// MARK: - Add Table Sheet

struct AddTableSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    let eventId: UUID

    @State private var name = ""
    @State private var capacity = 8

    var body: some View {
        NavigationStack {
            Form {
                Section("Table Details") {
                    TextField("Table name (e.g., Table 1)", text: $name)
                    Stepper("Capacity: \(capacity)", value: $capacity, in: 2...20)
                }
                Section {
                    Button("Add Multiple Tables (10)") {
                        addMultipleTables()
                    }
                }
            }
            .navigationTitle("Add Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSingleTable()
                    }
                }
            }
        }
    }

    private func addSingleTable() {
        let existingCount = (try? modelContext.fetchCount(FetchDescriptor<SeatingTable>(
            predicate: #Predicate { $0.eventId == eventId }
        ))) ?? 0

        let table = SeatingTable(
            name: name.isEmpty ? "Table \(existingCount + 1)" : name,
            capacity: capacity,
            eventId: eventId
        )
        modelContext.insert(table)
        modelContext.safeSave()
        HapticService.success()
        dismiss()
    }

    private func addMultipleTables() {
        let existingCount = (try? modelContext.fetchCount(FetchDescriptor<SeatingTable>(
            predicate: #Predicate { $0.eventId == eventId }
        ))) ?? 0

        for i in 1...10 {
            let table = SeatingTable(
                name: "Table \(existingCount + i)",
                capacity: capacity,
                eventId: eventId
            )
            modelContext.insert(table)
        }
        modelContext.safeSave()
        HapticService.success()
        dismiss()
    }
}

// MARK: - Assign Guests Sheet

struct AssignGuestsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    let event: Event
    @Bindable var table: SeatingTable

    var body: some View {
        NavigationStack {
            List {
                Section("Assigned (\(table.guestIds.count)/\(table.capacity))") {
                    ForEach(assignedGuests) { guest in
                        HStack {
                            Text(guest.name)
                            Spacer()
                            Button {
                                removeGuest(guest)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(Color.gatherError)
                            }
                        }
                    }
                }

                Section("Available Guests") {
                    ForEach(availableGuests) { guest in
                        HStack {
                            Text(guest.name)
                            if guest.plusOneCount > 0 {
                                Text("+\(guest.plusOneCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                assignGuest(guest)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentPurpleFallback)
                            }
                            .disabled(table.isFull)
                        }
                    }
                }
            }
            .navigationTitle(table.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var assignedGuests: [Guest] {
        event.guests.filter { table.guestIds.contains($0.id) }
    }

    private var availableGuests: [Guest] {
        event.guests.filter { !table.guestIds.contains($0.id) }
    }

    private func assignGuest(_ guest: Guest) {
        guard !table.isFull else { return }
        table.guestIds.append(guest.id)
        modelContext.safeSave()
        HapticService.selection()
    }

    private func removeGuest(_ guest: Guest) {
        table.guestIds.removeAll { $0 == guest.id }
        modelContext.safeSave()
    }
}

#Preview {
    SeatingChartView(event: Event(title: "Sample Wedding"))
}
