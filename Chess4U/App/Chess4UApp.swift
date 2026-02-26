import SwiftUI

@main
struct Chess4UApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environmentObject(appState)
                .preferredColorScheme(appState.settings.colorScheme)
        }
    }
}

struct ContentRootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.playerProfile == nil {
                NavigationView {
                    OnboardingView()
                }
                .navigationViewStyle(.stack)
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: appState.playerProfile == nil)
    }
}
