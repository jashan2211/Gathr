import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreateSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            TabView(selection: $appState.selectedTab) {
                HomeView()
                    .tag(AppState.Tab.home)

                MyEventsView()
                    .tag(AppState.Tab.myEvents)

                // Placeholder for create (handled by floating button)
                Color.clear
                    .tag(AppState.Tab.create)

                ContactsView()
                    .tag(AppState.Tab.contacts)

                ProfileView()
                    .tag(AppState.Tab.profile)
            }

            // Custom Tab Bar
            CustomTabBar(selectedTab: $appState.selectedTab) {
                showCreateSheet = true
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showCreateSheet) {
            CreateEventView()
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppState.Tab
    let onCreateTap: () -> Void

    private let tabs: [AppState.Tab] = [.home, .myEvents, .create, .contacts, .profile]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.rawValue) { tab in
                if tab == .create {
                    CreateButton(action: onCreateTap)
                        .offset(y: -10)
                } else {
                    TabBarButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xl)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let tab: AppState.Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: IconSize.lg))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.accentPurpleFallback : .gatherSecondaryText)

                Text(tab.title)
                    .font(GatherFont.caption2)
                    .foregroundStyle(isSelected ? Color.accentPurpleFallback : .gatherSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}

// MARK: - Create Button

struct CreateButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(LinearGradient.gatherAccentGradient)
                    .frame(width: 56, height: 56)
                    .shadow(color: .accentPurpleFallback.opacity(0.3), radius: 8, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: IconSize.lg, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .pressEvents {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = false
            }
        }
        .accessibilityLabel("Create Event")
    }
}

// MARK: - Press Events Modifier

struct PressEventsModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
