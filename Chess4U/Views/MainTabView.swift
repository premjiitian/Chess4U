import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case train = "Train"
        case board = "Board"
        case analyze = "Analyze"
        case lessons = "Lessons"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .train:     return "bolt.fill"
            case .board:     return "squareshape.split.2x2"
            case .analyze:   return "magnifyingglass"
            case .lessons:   return "books.vertical.fill"
            case .profile:   return "person.fill"
            }
        }
    }

    private var isKidsMode: Bool {
        appState.settings.uiMode == .kids
    }

    var body: some View {
        ZStack(alignment: .top) {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label(isKidsMode ? "Home" : "Dashboard", systemImage: isKidsMode ? "house.fill" : "house.fill") }
                .tag(Tab.dashboard)
                .accessibilityIdentifier("tab_dashboard")

            TrainingHubView()
                .tabItem { Label(isKidsMode ? "Practice" : "Train", systemImage: isKidsMode ? "star.fill" : "bolt.fill") }
                .tag(Tab.train)
                .accessibilityIdentifier("tab_train")

            FreePlayView()
                .tabItem { Label(isKidsMode ? "Play" : "Board", systemImage: "squareshape.split.2x2") }
                .tag(Tab.board)
                .accessibilityIdentifier("tab_board")

            ImportGamesView()
                .tabItem { Label("Analyze", systemImage: "magnifyingglass") }
                .tag(Tab.analyze)
                .accessibilityIdentifier("tab_analyze")

            LessonLibraryView()
                .tabItem { Label(isKidsMode ? "Learn" : "Lessons", systemImage: isKidsMode ? "lightbulb.fill" : "books.vertical.fill") }
                .tag(Tab.lessons)
                .accessibilityIdentifier("tab_lessons")

            ProfileView()
                .tabItem { Label(isKidsMode ? "Me" : "Profile", systemImage: "person.fill") }
                .tag(Tab.profile)
                .accessibilityIdentifier("tab_profile")
        }
        .accentColor(isKidsMode ? .orange : AppTheme.accent)

        // Achievement toast banner
        if let achievement = appState.pendingAchievement {
            AchievementToastView(achievement: achievement)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: appState.pendingAchievement?.id)
                .zIndex(100)
                .padding(.top, 8)
        }
        } // end ZStack
    }
}

// MARK: - Achievement Toast
struct AchievementToastView: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundColor(.yellow)
                .frame(width: 44, height: 44)
                .background(Color.yellow.opacity(0.2))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement Unlocked!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(achievement.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(achievement.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "trophy.fill")
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}
