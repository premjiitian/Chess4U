import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = DashboardViewModel()
    @ObservedObject private var puzzleService = DailyPuzzleService.shared
    @State private var showingDailyPuzzle = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting & Streak
                    greetingSection

                    // Daily Puzzle Card
                    dailyPuzzleCard

                    // Skill Progress Rings
                    if let profile = appState.playerProfile {
                        skillProgressRings(profile: profile)
                    }

                    // Skill Radar
                    if let profile = appState.playerProfile {
                        SkillRadarView(profile: profile)
                            .frame(height: 220)
                    }

                    // Recommended Training
                    recommendedTrainingCard

                    // Weekly Plan
                    weeklyPlanSection

                    // Recent Achievements
                    if !appState.achievements.isEmpty {
                        achievementsSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Chess4U")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let profile = appState.playerProfile {
                        NavigationLink(destination: ProfileView()) {
                            HStack(spacing: 4) {
                                Text(profile.band.icon)
                                Text(profile.name)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            if let profile = appState.playerProfile {
                vm.load(profile: profile, achievements: appState.achievements, streak: appState.trainingStreak)
            }
        }
        .sheet(isPresented: $showingDailyPuzzle) {
            DailyPuzzleView()
                .environmentObject(appState)
        }
    }

    var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.title2)
                    .fontWeight(.bold)
                if let profile = appState.playerProfile {
                    Text(profile.band.rawValue + " · Elo \(profile.elo)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text(vm.motivationalMessage)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 2)
            }
            Spacer()
            VStack {
                Text("🔥 \(appState.trainingStreak)")
                    .font(.title)
                Text("Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = appState.playerProfile?.name ?? "Player"
        switch hour {
        case 5..<12: return "Good morning, \(name)!"
        case 12..<17: return "Good afternoon, \(name)!"
        case 17..<22: return "Good evening, \(name)!"
        default: return "Hello, \(name)!"
        }
    }

    var dailyPuzzleCard: some View {
        Button { showingDailyPuzzle = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(puzzleService.isCompleted ? Color.green : Color.orange)
                        .frame(width: 56, height: 56)
                    Image(systemName: puzzleService.isCompleted ? "checkmark" : "puzzlepiece.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Daily Puzzle")
                            .font(.headline)
                            .foregroundColor(.primary)
                        if puzzleService.isCompleted {
                            Text("Solved!")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(6)
                        }
                    }
                    if let puzzle = puzzleService.todaysPuzzle {
                        Text(puzzle.theme.rawValue.capitalized + " · Rating \(puzzle.rating)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Streak: \(puzzleService.streak) days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: puzzleService.isCompleted
                        ? [Color.green.opacity(0.08), Color.green.opacity(0.04)]
                        : [Color.orange.opacity(0.12), Color.yellow.opacity(0.06)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(puzzleService.isCompleted ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }

    func skillProgressRings(profile: PlayerProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Skill Progress")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 20) {
                SkillRingView(label: "Tactics", value: profile.tacticsAccuracy, color: .red)
                SkillRingView(label: "Strategy", value: profile.strategyScore, color: .blue)
                SkillRingView(label: "Endgame", value: profile.endgameAccuracy, color: .green)
                SkillRingView(label: "Openings", value: profile.openingAccuracy, color: .orange)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    var recommendedTrainingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("AI Recommends Today")
                    .font(.headline)
                Spacer()
                Text("Personalized")
                    .font(.caption)
                    .foregroundColor(.purple)
                    .padding(4)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(6)
            }

            let training = vm.recommendedTraining
            NavigationLink(destination: TrainingSessionView(trainingType: training)) {
                HStack(spacing: 16) {
                    Image(systemName: training.icon)
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.blue)
                        .cornerRadius(14)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(training.rawValue)
                            .font(.headline)
                        Text("~\(training.estimatedMinutes) min · Optimized for your level")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color.blue.opacity(0.08))
                .cornerRadius(14)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    var weeklyPlanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.green)
                Text("This Week's Plan")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: WeeklyPlanView()) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            if let plan = appState.weeklyPlan {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(plan.dailyPlans.prefix(4)) { day in
                        DayPlanCard(plan: day)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                Text("Recent Achievements")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: AchievementsView()) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            HStack(spacing: 12) {
                ForEach(vm.recentAchievements) { achievement in
                    AchievementBadge(achievement: achievement)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Day Plan Card
struct DayPlanCard: View {
    let plan: DailyPlan
    @State private var isCompleted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(plan.dayOfWeek.prefix(3))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if plan.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }

            ForEach(plan.trainingTypes, id: \.self) { type in
                HStack(spacing: 4) {
                    Image(systemName: type.icon)
                        .font(.caption2)
                    Text(type.rawValue)
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }

            Text("\(plan.estimatedMinutes) min")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(plan.isCompleted ? Color.green.opacity(0.1) : Color(.systemGroupedBackground))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
    }
}

// MARK: - Skill Ring View
struct SkillRingView: View {
    let label: String
    let value: Double   // 0.0 ... 1.0
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(min(value, 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: value)
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
            }
            .frame(width: 56, height: 56)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Achievement Badge
struct AchievementBadge: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundColor(.yellow)
                .frame(width: 44, height: 44)
                .background(Color.yellow.opacity(0.15))
                .cornerRadius(10)

            Text(achievement.title)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 70)
    }
}
