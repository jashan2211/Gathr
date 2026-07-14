import SwiftUI

struct FunctionsTab: View {
    @Bindable var event: Event
    @EnvironmentObject var authManager: AuthManager
    @State private var showAddFunction = false
    @State private var selectedFunction: EventFunction?
    @State private var liveActivityOn = false

    /// Adding/editing functions is host-only; invitees only view the schedule.
    private var isHost: Bool { event.isHosted(by: authManager.currentUser) }

    var body: some View {
        // Content-only: EventDetailView owns the page scroll.
        Group {
            VStack(spacing: Spacing.md) {
                if event.functions.isEmpty {
                    emptyState
                } else {
                    functionsGrid
                }
            }
            .horizontalPadding()
            .padding(.top, Spacing.md)
            .padding(.bottom, Layout.scrollBottomInset)
        }
        .sheet(isPresented: $showAddFunction) {
            AddFunctionSheet(event: event)
        }
        .sheet(item: $selectedFunction) { function in
            FunctionDetailSheet(function: function, event: event)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        if isHost {
            GatherEmptyState(
                icon: "calendar.day.timeline.left",
                title: "No Functions Yet",
                message: "Add your first function like Mehendi, Sangeet, Ceremony, or Reception",
                actionTitle: "Add Function",
                action: { showAddFunction = true }
            )
            .padding(.vertical, Spacing.xxl)
        } else {
            // Invitee voice — no host CTA when the schedule isn't up yet.
            GatherEmptyState(
                icon: "calendar.day.timeline.left",
                title: "Schedule Coming Soon",
                message: "The host hasn't added the functions yet — check back for the full schedule."
            )
            .padding(.vertical, Spacing.xxl)
        }
    }

    // MARK: - Functions Grid

    private var functionsGrid: some View {
        VStack(spacing: Spacing.md) {
            // Header with Add button
            HStack {
                Text("\(event.functions.count) Function\(event.functions.count == 1 ? "" : "s")")
                    .gatherSectionHeader()
                    .foregroundStyle(Color.gatherPrimaryText)

                Spacer()

                if hasLiveContent {
                    liveActivityButton
                }

                if isHost {
                    Button {
                        showAddFunction = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(GatherFont.callout)
                            .foregroundStyle(Color.accentPurpleFallback)
                    }
                }
            }

            // Timeline Function Cards, grouped by day when the schedule
            // spans multiple days (weddings: Mehendi Fri, Ceremony Sat...).
            VStack(spacing: 0) {
                ForEach(functionsByDay, id: \.day) { group in
                    if spansMultipleDays {
                        dayHeader(group.day)
                    }

                    ForEach(Array(group.functions.enumerated()), id: \.element.id) { index, function in
                        HStack(alignment: .top, spacing: Spacing.md) {
                            // Timeline connector
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(function.date > Date()
                                          ? LinearGradient(colors: [Color.accentPurpleFallback, Color.accentPinkFallback], startPoint: .top, endPoint: .bottom)
                                          : LinearGradient(colors: [Color.rsvpYesFallback, Color.rsvpYesFallback], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 14, height: 14)

                                if index < group.functions.count - 1 {
                                    Rectangle()
                                        .fill(Color.gatherSecondaryText.opacity(0.2))
                                        .frame(width: 2)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 14)

                            // Function Card
                            FunctionCard(
                                function: function,
                                event: event,
                                isNextUp: function.id == nextUpFunctionId
                            )
                            .onTapGesture {
                                HapticService.selection()
                                selectedFunction = function
                            }
                        }
                        .bouncyAppear(delay: Double(index) * 0.05)
                    }
                }
            }
        }
    }

    private func dayHeader(_ day: Date) -> some View {
        Text(dayHeaderText(day))
            .gatherEyebrow()
            .foregroundStyle(Color.gatherSecondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)
            .accessibilityAddTraits(.isHeader)
    }

    private func dayHeaderText(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) {
            return "TODAY"
        } else if Calendar.current.isDateInTomorrow(day) {
            return "TOMORROW"
        }
        return GatherDateFormatter.shortWeekdayMonthDay.string(from: day).uppercased()
    }

    private var sortedFunctions: [EventFunction] {
        event.functions.sorted { $0.date < $1.date }
    }

    /// Functions bucketed by calendar day, days in chronological order.
    /// `Dictionary(grouping:)` preserves the sorted order within each bucket.
    private var functionsByDay: [(day: Date, functions: [EventFunction])] {
        Dictionary(grouping: sortedFunctions) { Calendar.current.startOfDay(for: $0.date) }
            .sorted { $0.key < $1.key }
            .map { (day: $0.key, functions: $0.value) }
    }

    private var spansMultipleDays: Bool {
        functionsByDay.count > 1
    }

    /// The first function that hasn't ended yet — gets the "next up" accent.
    private var nextUpFunctionId: UUID? {
        sortedFunctions.first { !$0.isPast }?.id
    }

    // MARK: - Live Activity

    /// Only offer a Live Activity when there's a function still happening or upcoming.
    private var hasLiveContent: Bool {
        event.functions.contains { !$0.isPast }
    }

    /// Start/stop the Lock Screen + Dynamic Island "event day" Live Activity.
    private var liveActivityButton: some View {
        Button {
            if liveActivityOn {
                LiveActivityService.shared.end(for: event.id)
                liveActivityOn = false
            } else {
                liveActivityOn = LiveActivityService.shared.start(for: event)
            }
            HapticService.buttonTap()
        } label: {
            Label(liveActivityOn ? "Live" : "Go Live",
                  systemImage: liveActivityOn ? "dot.radiowaves.left.and.right" : "livephoto")
                .font(GatherFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(liveActivityOn ? .white : Color.accentPurpleFallback)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 6)
                .background(
                    liveActivityOn
                        ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                        : AnyShapeStyle(Color.accentPurpleFallback.opacity(0.12))
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(liveActivityOn ? "Stop Live Activity" : "Start Live Activity")
        .onAppear { liveActivityOn = LiveActivityService.shared.isActive(for: event.id) }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var previewEvent = Event(
        title: "Wedding Celebration",
        startDate: Date()
    )
    FunctionsTab(event: previewEvent)
}
