import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "♟",
            title: "Welcome to Chess4U",
            subtitle: "Your AI Chess Trainer",
            description: "Train like a professional. Improve your game with personalized coaching, adaptive puzzles, and expert lessons.",
            color: .blue
        ),
        OnboardingPage(
            icon: "🧠",
            title: "AI-Powered Coaching",
            subtitle: "Tree-of-Thought Training",
            description: "Our AI analyzes your play and selects the perfect training for your level. From 800 to 2000 Elo — we've got you.",
            color: .purple
        ),
        OnboardingPage(
            icon: "📈",
            title: "Track Your Progress",
            subtitle: "Adaptive Learning",
            description: "The app adjusts difficulty automatically based on your performance. Earn achievements and build training streaks.",
            color: .green
        ),
        OnboardingPage(
            icon: "🎯",
            title: "Ready to Improve?",
            subtitle: "Let's Set Up Your Profile",
            description: "Tell us about your current level and goals. We'll create your personalized training plan.",
            color: .orange
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    pages[currentPage].color.opacity(0.3),
                    Color(.systemBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { idx in
                        OnboardingPageView(page: pages[idx])
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: UIScreen.main.bounds.height * 0.65)

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { idx in
                        Circle()
                            .fill(idx == currentPage ? pages[currentPage].color : Color.gray.opacity(0.4))
                            .frame(width: idx == currentPage ? 10 : 7,
                                   height: idx == currentPage ? 10 : 7)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.top, 16)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    if currentPage < pages.count - 1 {
                        Button {
                            withAnimation { currentPage += 1 }
                        } label: {
                            HStack {
                                Text("Next")
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(pages[currentPage].color)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .font(.headline)
                        }
                    } else {
                        NavigationLink(destination: PlayerAssessmentView()) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Start My Training Journey")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(colors: [.blue, .purple],
                                                       startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .font(.headline)
                        }
                    }

                    // Guest mode — always visible
                    Button("Play as Guest") {
                        createGuestProfile()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation { currentPage -= 1 }
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
    }

    func createGuestProfile() {
        var profile = PlayerProfile(
            name: "Guest",
            elo: 800,
            preferredTimeControl: .rapid,
            playerType: .casual,
            mainOpeningsWhite: [],
            mainDefensesBlack: [],
            ratingTrend: .stable,
            weaknesses: [.tactics, .openings]
        )
        profile.tacticsAccuracy = 0.3
        profile.openingAccuracy = 0.3
        profile.endgameAccuracy = 0.3
        profile.calculationScore = 0.3
        profile.strategyScore = 0.3
        appState.savePlayerProfile(profile)
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(page.icon)
                .font(.system(size: 80))
                .shadow(radius: 10)

            VStack(spacing: 8) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.title3)
                    .foregroundColor(page.color)
                    .fontWeight(.semibold)
            }

            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineSpacing(4)

            Spacer()
        }
        .padding()
    }
}
