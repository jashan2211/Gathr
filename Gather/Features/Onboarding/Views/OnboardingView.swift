import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    @State private var selectedRole: UserRole = .both
    @State private var selectedCategories: Set<EventCategory> = []

    private let totalPages = 4

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.accentPurpleFallback.opacity(0.05),
                    Color.gatherBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    rolePage.tag(1)
                    interestsPage.tag(2)
                    readyPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom section
                VStack(spacing: Spacing.md) {
                    // Page indicators
                    HStack(spacing: Spacing.xs) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Color.accentPurpleFallback : Color.gatherSecondaryText.opacity(0.3))
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }

                    // Buttons
                    HStack {
                        if currentPage > 0 {
                            Button {
                                withAnimation { currentPage -= 1 }
                            } label: {
                                Text("Back")
                                    .font(GatherFont.callout)
                                    .foregroundStyle(Color.gatherSecondaryText)
                            }
                        }

                        Spacer()

                        if currentPage < totalPages - 1 {
                            Button {
                                withAnimation { currentPage += 1 }
                            } label: {
                                HStack(spacing: Spacing.xs) {
                                    Text("Next")
                                    Image(systemName: "arrow.right")
                                }
                                .font(GatherFont.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.sm)
                                .background(LinearGradient.gatherAccentGradient)
                                .clipShape(Capsule())
                            }
                        }
                    }

                    // Skip button
                    if currentPage < totalPages - 1 {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Skip")
                                .font(GatherFont.callout)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // App icon
            ZStack {
                Circle()
                    .fill(LinearGradient.gatherAccentGradient)
                    .frame(width: 120, height: 120)

                Image(systemName: "party.popper.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.accentPurpleFallback.opacity(0.3), radius: 20, y: 10)

            VStack(spacing: Spacing.sm) {
                Text("Welcome to Gather")
                    .font(GatherFont.title)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text("Your all-in-one event platform for creating, managing, and discovering amazing events")
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            // Feature highlights
            VStack(spacing: Spacing.md) {
                featureRow(icon: "sparkles", title: "Create Events", subtitle: "Weddings, parties, concerts & more")
                featureRow(icon: "person.2.fill", title: "Manage Guests", subtitle: "Invites, RSVPs, and check-ins")
                featureRow(icon: "ticket.fill", title: "Sell Tickets", subtitle: "Tiers, promo codes, group discounts")
                featureRow(icon: "magnifyingglass", title: "Discover", subtitle: "Find events near you")
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentPurpleFallback.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color.accentPurpleFallback)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(GatherFont.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text(subtitle)
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            Spacer()
        }
    }

    // MARK: - Page 2: Role

    private var rolePage: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentPurpleFallback)

            VStack(spacing: Spacing.sm) {
                Text("How will you use Gather?")
                    .font(GatherFont.title2)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text("This helps us personalize your experience")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            VStack(spacing: Spacing.md) {
                roleCard(.host, icon: "crown.fill", title: "I'm a Host", subtitle: "I create and manage events")
                roleCard(.attendee, icon: "person.fill", title: "I'm an Attendee", subtitle: "I discover and attend events")
                roleCard(.both, icon: "arrow.left.arrow.right", title: "Both", subtitle: "I host and attend events")
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
    }

    private func roleCard(_ role: UserRole, icon: String, title: String, subtitle: String) -> some View {
        Button {
            selectedRole = role
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(selectedRole == role ? Color.accentPurpleFallback : Color.gatherSecondaryBackground)
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(selectedRole == role ? .white : Color.gatherSecondaryText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text(subtitle)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                Image(systemName: selectedRole == role ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectedRole == role ? Color.accentPurpleFallback : Color.gatherSecondaryText.opacity(0.3))
            }
            .padding(Spacing.md)
            .background(Color.gatherSecondaryBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(selectedRole == role ? Color.accentPurpleFallback : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page 3: Interests

    private var interestsPage: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentPurpleFallback)

            VStack(spacing: Spacing.sm) {
                Text("What interests you?")
                    .font(GatherFont.title2)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text("Pick your favorite event types")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                ForEach(EventCategory.allCases, id: \.self) { category in
                    interestCard(category)
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
    }

    private func interestCard(_ category: EventCategory) -> some View {
        let isSelected = selectedCategories.contains(category)

        return Button {
            if isSelected {
                selectedCategories.remove(category)
            } else {
                selectedCategories.insert(category)
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            VStack(spacing: Spacing.sm) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : Color.accentPurpleFallback)

                Text(category.displayName)
                    .font(GatherFont.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(isSelected ? Color.accentPurpleFallback : Color.gatherSecondaryBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(isSelected ? Color.accentPurpleFallback : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page 4: Ready

    private var readyPage: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.rsvpYesFallback.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.rsvpYesFallback)
            }

            VStack(spacing: Spacing.sm) {
                Text("You're all set!")
                    .font(GatherFont.title)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text("Start exploring events or create your first one")
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            Button {
                completeOnboarding()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text("Get Started")
                    Image(systemName: "arrow.right")
                }
                .font(GatherFont.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(LinearGradient.gatherAccentGradient)
                .clipShape(Capsule())
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Complete

    private func completeOnboarding() {
        // Save preferences
        UserDefaults.standard.set(selectedRole.rawValue, forKey: "userRole")
        UserDefaults.standard.set(selectedCategories.map { $0.rawValue }, forKey: "preferredCategories")

        withAnimation(.easeInOut(duration: 0.3)) {
            hasCompletedOnboarding = true
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - User Role

enum UserRole: String, CaseIterable {
    case host
    case attendee
    case both
}
