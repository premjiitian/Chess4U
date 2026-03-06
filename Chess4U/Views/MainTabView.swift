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
    }
}
