import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = DashboardViewModel()
    @State private var showingTrainingSession: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting & Streak
                    greetingSection

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
