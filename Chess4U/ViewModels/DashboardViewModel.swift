import SwiftUI
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var recommendedTraining: TrainingType = .tactics
    @Published var weeklyPlan: WeeklyTrainingPlan?
    @Published var todaysPlan: DailyPlan?
    @Published var recentAchievements: [Achievement] = []
    @Published var sessionHistory: [TrainingSession] = []
    @Published var motivationalMessage: String = ""

    private let thoughtEngine = TreeOfThoughtEngine.shared
    private let persistence = PersistenceService.shared

    func load(profile: PlayerProfile, achievements: [Achievement], streak: Int) {
        sessionHistory = persistence.loadSessionHistory()
        recommendedTraining = thoughtEngine.selectTrainingPath(for: profile, sessionHistory: sessionHistory)
        weeklyPlan = WeeklyTrainingPlan.generate(for: profile)
        todaysPlan = weeklyPlan?.dailyPlans.first(where: { $0.dayNumber == currentDayNumber })
        recentAchievements = Array(achievements.suffix(3))
        motivationalMessage = generateMotivation(profile: profile, streak: streak)
    }

    private var currentDayNumber: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }

    private func generateMotivation(profile: PlayerProfile, streak: Int) -> String {
        let messages: [PlayerBand: [String]] = [
            .bandA: [
                "Every grandmaster was once a beginner. Keep going!",
                "Today's practice builds tomorrow's intuition.",
                "Small steps, big improvements. You've got this!"
            ],
            .bandB: [
                "Pattern recognition is the key to chess improvement.",
                "Each puzzle you solve builds your chess vision.",
                "Consistency beats talent when talent doesn't work."
            ],
            .bandC: [
                "Calculate deeper today than you did yesterday.",
                "Strong players don't find tactics — they see them.",
                "Your calculation is improving with every session."
            ],
            .bandD: [
                "Think prophylactically: prevent before attacking.",
                "The hallmark of a strong player is strategic clarity.",
                "Master one concept at a time, master them all."
            ],
            .bandE: [
                "Depth of calculation separates masters from experts.",
                "Every position has a truth — find it.",
                "Tournament preparation starts today."
            ]
        ]

        let bandMessages = messages[profile.band] ?? messages[.bandA]!
        let streakBonus = streak > 0 ? " \(streak) day streak — keep it up!" : ""
        return (bandMessages.randomElement() ?? "") + streakBonus
    }

    var skillData: [(String, Double)] {
        return [] // Populated from profile
    }
}
