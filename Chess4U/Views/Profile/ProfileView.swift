import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingEloUpdate = false
    @State private var newEloString = ""
    @State private var showingResetConfirm = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let profile = appState.playerProfile {
                        // Profile Header
                        profileHeader(profile)

                        // Stats Grid
                        statsGrid(profile)

                        // Skill Breakdown
                        skillBreakdown(profile)

                        // Training History
                        trainingHistory

                        // Achievements Preview
                        NavigationLink(destination: AchievementsView()) {
                            achievementsPreview
                        }
                        .buttonStyle(.plain)

                        // Settings Link
                        NavigationLink(destination: SettingsView()) {
                            settingsRow
                        }
                        .buttonStyle(.plain)

                        // Reset
                        Button {
                            showingResetConfirm = true
                        } label: {
                            Text("Reset Profile")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newEloString = "\(appState.playerProfile?.elo ?? 1200)"
                        showingEloUpdate = true
                    } label: {
                        Label("Update Elo", systemImage: "pencil")
                    }
                }
            }
            .alert("Update Elo Rating", isPresented: $showingEloUpdate) {
                TextField("New Elo", text: $newEloString)
                    .keyboardType(.numberPad)
                Button("Update") {
                    if var profile = appState.playerProfile, let elo = Int(newEloString) {
                        profile.elo = elo
                        appState.savePlayerProfile(profile)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Reset Profile?", isPresented: $showingResetConfirm) {
                Button("Reset", role: .destructive) {
                    PersistenceService.shared.resetAllData()
                    appState.playerProfile = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all your progress and achievements. This cannot be undone.")
            }
        }
        .navigationViewStyle(.stack)
    }

    func profileHeader(_ profile: PlayerProfile) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                Text(String(profile.name.prefix(1)).uppercased())
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 4) {
                Text(profile.name)
                    .font(.title2)
                    .fontWeight(.bold)
                HStack {
                    Text(profile.band.icon)
                    Text(profile.band.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("Elo \(profile.elo) · \(profile.playerType.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Streak badge
            HStack(spacing: 8) {
                Label("\(appState.trainingStreak) day streak", systemImage: "flame.fill")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(20)

                Label("\(profile.sessionsCompleted) sessions", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
    }

    func statsGrid(_ profile: PlayerProfile) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            StatCard(value: "\(profile.elo)", label: "Elo Rating", icon: "speedometer", color: .blue)
            StatCard(value: "\(profile.totalPuzzlesSolved)", label: "Puzzles", icon: "puzzle", color: .purple)
            StatCard(value: "\(profile.sessionsCompleted)", label: "Sessions", icon: "checkmark.circle", color: .green)
            StatCard(value: "\(Int(profile.tacticsAccuracy))%", label: "Tactics", icon: "bolt", color: .yellow)
            StatCard(value: "\(Int(profile.endgameAccuracy))%", label: "Endgames", icon: "flag", color: .teal)
            StatCard(value: "\(appState.trainingStreak)", label: "Streak", icon: "flame", color: .orange)
        }
    }

    func skillBreakdown(_ profile: PlayerProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Skill Breakdown")
                .font(.headline)

            ForEach([
                ("Tactics", profile.tacticsAccuracy, Color.yellow),
                ("Openings", profile.openingAccuracy, Color.blue),
                ("Endgames", profile.endgameAccuracy, Color.green),
                ("Calculation", profile.calculationScore, Color.purple),
                ("Strategy", profile.strategyScore, Color.orange)
            ], id: \.0) { skill, value, color in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(skill)
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(value))%")
                            .font(.caption)
                            .foregroundColor(color)
                            .fontWeight(.semibold)
                    }
                    ProgressView(value: value / 100)
                        .tint(color)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    var trainingHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weaknesses to Work On")
                .font(.headline)

            if let profile = appState.playerProfile, !profile.weaknesses.isEmpty {
                ForEach(profile.weaknesses, id: \.self) { weakness in
                    HStack {
                        Image(systemName: weakness.icon)
                            .foregroundColor(.red)
                        Text(weakness.rawValue)
                            .font(.subheadline)
                        Spacer()
                        NavigationLink(destination: TrainingSessionView(
                            trainingType: trainingTypeFor(weakness))) {
                            Text("Train")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    var achievementsPreview: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundColor(.yellow)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Achievements")
                    .font(.headline)
                Text("\(appState.achievements.count) earned")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    var settingsRow: some View {
        HStack {
            Image(systemName: "gear")
                .foregroundColor(.gray)
                .font(.title2)
            Text("Settings")
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    func trainingTypeFor(_ weakness: WeaknessArea) -> TrainingType {
        switch weakness {
        case .tactics: return .tactics
        case .blunders: return .blunderReduction
        case .strategy: return .middlegame
        case .endgames: return .endgame
        case .openings: return .openings
        case .calculation: return .calculation
        case .timeManagement: return .blunderReduction
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}
