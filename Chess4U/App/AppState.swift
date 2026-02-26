import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var playerProfile: PlayerProfile?
    @Published var settings: AppSettings = AppSettings()
    @Published var activeTrainingSession: TrainingSession?
    @Published var weeklyPlan: WeeklyTrainingPlan?
    @Published var achievements: [Achievement] = []
    @Published var trainingStreak: Int = 0

    private let persistence = PersistenceService.shared

    init() {
        loadSavedData()
    }

    func loadSavedData() {
        playerProfile = persistence.loadPlayerProfile()
        settings = persistence.loadSettings()
        achievements = persistence.loadAchievements()
        trainingStreak = persistence.loadStreak()
        if let profile = playerProfile {
            weeklyPlan = WeeklyTrainingPlan.generate(for: profile)
        }
    }

    func savePlayerProfile(_ profile: PlayerProfile) {
        playerProfile = profile
        weeklyPlan = WeeklyTrainingPlan.generate(for: profile)
        persistence.savePlayerProfile(profile)
        checkAndAwardAchievements()
    }

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        persistence.saveSettings(newSettings)
    }

    func recordSessionCompletion(session: TrainingSession) {
        trainingStreak += 1
        persistence.saveStreak(trainingStreak)
        if var profile = playerProfile {
            profile.sessionsCompleted += 1
            profile.totalPuzzlesSolved += session.puzzlesSolved
            profile.lastSessionDate = Date()
            savePlayerProfile(profile)
        }
        checkAndAwardAchievements()
    }

    private func checkAndAwardAchievements() {
        guard let profile = playerProfile else { return }
        var newAchievements: [Achievement] = []
        let earned = Set(achievements.map { $0.id })

        for achievement in Achievement.allAchievements {
            guard !earned.contains(achievement.id) else { continue }
            if achievement.isEarned(profile: profile, streak: trainingStreak) {
                newAchievements.append(achievement)
            }
        }

        if !newAchievements.isEmpty {
            achievements.append(contentsOf: newAchievements)
            persistence.saveAchievements(achievements)
        }
    }
}
