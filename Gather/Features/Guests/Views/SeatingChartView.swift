import SwiftUI

struct SeatingChartView: View {
    @Bindable var event: Event
    @State private var tables: [Table] = []
    @State private var showAddTable = false
    @State private var selectedTable: Table?
    @State private var showAssignGuests = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Stats
                    seatingStats

                    // Tables Grid
                    if tables.isEmpty {
                        emptyState
                    } else {
                        tablesGrid
                    }

                    // Unassigned Guests
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
                AddTableSheet(tables: $tables)
            }
            .sheet(isPresented: $showAssignGuests) {
                if let table = selectedTable {
                    AssignGuestsSheet(event: event, table: Binding(
                        get: { table },
                        set: { newValue in
                            if let index = tables.firstIndex(where: { $0.id == table.id }) {
                                tables[index] = newValue
                            }
                        }
                    ))
                }
            }
        }
    }

    // MARK: - Seating Stats

    private var seatingStats: some View {
        HStack(spacing: Spacing.lg) {
            StatCard(
                title: "Tables",
                value: "\(tables.count)",
                icon: "tablecells"
            )

            StatCard(
                title: "Seated",
                value: "\(seatedCount)",
                icon: "person.fill.checkmark"
            )

            StatCard(
                title: "Unassigned",
                value: "\(unassignedGuests.count)",
                icon: "person.fill.questionmark"
            )
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
            ForEach($tables) { $table in
                TableCard(table: $table) {
                    selectedTable = table
                    showAssignGuests = true
                } onDelete: {
                    tables.removeAll { $0.id == table.id }
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

// MARK: - Table Model

struct Table: Identifiable {
    let id: UUID
    var name: String
    var capacity: Int
    var guestIds: [UUID]

    init(id: UUID = UUID(), name: String, capacity: Int = 8, guestIds: [UUID] = []) {
        self.id = id
        self.name = name
        self.capacity = capacity
        self.guestIds = guestIds
    }

    var remainingSeats: Int {
        capacity - guestIds.count
    }

    var isFull: Bool {
        guestIds.count >= capacity
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
    @Binding var table: Table
    let onAssign: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Table icon
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

            // Progress indicator
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gatherSecondaryBackground)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(table.isFull ? Color.gatherSuccess : Color.accentPurpleFallback)
                        .frame(
                            width: geometry.size.width * CGFloat(table.guestIds.count) / CGFloat(table.capacity),
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
    @Binding var tables: [Table]

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
                    Button("Add Multiple Tables") {
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
                        let table = Table(
                            name: name.isEmpty ? "Table \(tables.count + 1)" : name,
                            capacity: capacity
                        )
                        tables.append(table)
                        dismiss()
                    }
                }
            }
        }
    }

    private func addMultipleTables() {
        for i in 1...10 {
            let table = Table(name: "Table \(tables.count + i)", capacity: capacity)
            tables.append(table)
        }
        dismiss()
    }
}

// MARK: - Assign Guests Sheet

struct AssignGuestsSheet: View {
    @Environment(\.dismiss) var dismiss
    let event: Event
    @Binding var table: Table

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
    }

    private func removeGuest(_ guest: Guest) {
        table.guestIds.removeAll { $0 == guest.id }
    }
}

#Preview {
    SeatingChartView(event: Event(title: "Sample Wedding"))
}
