import SwiftUI

struct FunctionsTab: View {
    @Bindable var event: Event
    @State private var showAddFunction = false
    @State private var selectedFunction: EventFunction?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if event.functions.isEmpty {
                    emptyState
                } else {
                    functionsGrid
                }
            }
            .padding(.horizontal)
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

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.accentPurpleFallback.opacity(0.08))
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(Color.accentPinkFallback.opacity(0.06))
                    .frame(width: 70, height: 70)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(LinearGradient.gatherAccentGradient)
            }

            VStack(spacing: Spacing.sm) {
                Text("No Functions Yet")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text("Add your first function like Mehendi, Sangeet, Ceremony, or Reception")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddFunction = true
            } label: {
                Label("Add Function", systemImage: "plus.circle.fill")
                    .font(GatherFont.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.sm)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, Spacing.xxxl)
    }

    // MARK: - Functions Grid

    private var functionsGrid: some View {
        VStack(spacing: Spacing.md) {
            // Header with Add button
            HStack {
                Text("\(event.functions.count) Function\(event.functions.count == 1 ? "" : "s")")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)

                Spacer()

                Button {
                    showAddFunction = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.accentPurpleFallback)
                }
            }

            // Timeline Function Cards
            VStack(spacing: 0) {
                ForEach(Array(sortedFunctions.enumerated()), id: \.element.id) { index, function in
                    HStack(alignment: .top, spacing: Spacing.md) {
                        // Timeline connector
                        VStack(spacing: 0) {
                            Circle()
                                .fill(function.date > Date()
                                      ? LinearGradient(colors: [Color.accentPurpleFallback, Color.accentPinkFallback], startPoint: .top, endPoint: .bottom)
                                      : LinearGradient(colors: [Color.rsvpYesFallback, Color.rsvpYesFallback], startPoint: .top, endPoint: .bottom))
                                .frame(width: 14, height: 14)

                            if index < sortedFunctions.count - 1 {
                                Rectangle()
                                    .fill(Color.gatherSecondaryText.opacity(0.2))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(width: 14)

                        // Function Card
                        FunctionCard(function: function, event: event)
                            .onTapGesture {
                                selectedFunction = function
                            }
                    }
                    .bouncyAppear(delay: Double(index) * 0.05)
                }
            }
        }
    }

    private var sortedFunctions: [EventFunction] {
        event.functions.sorted { $0.date < $1.date }
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
