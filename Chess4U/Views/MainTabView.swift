import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case train = "Train"
        case board = "Board"
        case lessons = "Lessons"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .train: return "bolt.fill"
            case .board: return "squareshape.split.2x2"
            case .lessons: return "books.vertical.fill"
            case .profile: return "person.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }
                .tag(Tab.dashboard)

            TrainingHubView()
                .tabItem { Label("Train", systemImage: "bolt.fill") }
                .tag(Tab.train)

            FreePlayView()
                .tabItem { Label("Board", systemImage: "squareshape.split.2x2") }
                .tag(Tab.board)

            LessonLibraryView()
                .tabItem { Label("Lessons", systemImage: "books.vertical.fill") }
                .tag(Tab.lessons)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(Tab.profile)
        }
        .accentColor(AppTheme.accent)
    }
}
