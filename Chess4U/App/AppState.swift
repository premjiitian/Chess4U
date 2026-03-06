import SwiftUI
import Combine
import StoreKit

class AppState: ObservableObject {
    @Published var playerProfile: PlayerProfile?
    @Published var settings: AppSettings = AppSettings()
    @Published var activeTrainingSession: TrainingSession?
    @Published var weeklyPlan: WeeklyTrainingPlan?
    @Published var achievements: [Achievement] = []
    @Published var trainingStreak: Int = 0

    private let persistence = PersistenceService.shared

    init() {
        if ProcessInfo.processInfo.arguments.contains("-SCREENSHOT_MODE") {
            seedScreenshotData()
        }
        loadSavedData()
    }

    private func seedScreenshotData() {
        let persistence = PersistenceService.shared
        persistence.resetAllData()

        var profile = PlayerProfile(
            name: "Alex",
            elo: 1450,
            preferredTimeControl: .rapid,
            playerType: .casual,
            mainOpeningsWhite: ["Italian Game", "London System"],
            mainDefensesBlack: ["Sicilian Defense"],
            ratingTrend: .improving,
            weaknesses: [.endgames, .calculation]
        )
        profile.sessionsCompleted = 23
        profile.totalPuzzlesSolved = 127
        profile.lastSessionDate = Date()
        profile.tacticsAccuracy = 0.72
        profile.openingAccuracy = 0.58
        profile.endgameAccuracy = 0.45
        profile.calculationScore = 0.63
        profile.strategyScore = 0.51
        persistence.savePlayerProfile(profile)
        persistence.saveStreak(7)

        let types: [TrainingType] = [.tactics, .openings, .endgame, .calculation]
        let sessions: [TrainingSession] = (0..<7).map { i in
            let solved = Int.random(in: 8...18)
            let attempted = solved + Int.random(in: 0...4)
            let correct = Int(Double(solved * 6) * Double.random(in: 0.85...1.0))
            let total = correct + Int.random(in: 2...8)
            let start = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let end = start.addingTimeInterval(Double.random(in: 900...1800))
            return TrainingSession(
                type: types[i % types.count],
                playerBand: .bandC,
                startDate: start,
                endDate: end,
                puzzlesSolved: solved,
                puzzlesAttempted: attempted,
                correctMoves: correct,
                totalMoves: total
            )
        }
        persistence.saveSessionHistory(sessions)
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
            // Prompt for App Store review after 5, 20, and 50 sessions
            let milestones = [5, 20, 50]
            if milestones.contains(profile.sessionsCompleted) {
                requestAppStoreReview()
            }
        }
        checkAndAwardAchievements()
    }

    func recordGameCompleted() {
        // Called after each free-play game finishes
        let key = "Chess4U_GamesPlayed"
        let count = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(count, forKey: key)
        let milestones = [5, 25, 100]
        if milestones.contains(count) {
            requestAppStoreReview()
        }
    }

    private func requestAppStoreReview() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
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
