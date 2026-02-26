import Foundation

// MARK: - Achievement
struct Achievement: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var description: String
    var icon: String
    var category: AchievementCategory
    var rarity: AchievementRarity
    var earnedDate: Date?

    var isEarned: Bool { earnedDate != nil }

    func isEarned(profile: PlayerProfile, streak: Int) -> Bool {
        switch id {
        case "first_puzzle":        return profile.totalPuzzlesSolved >= 1
        case "puzzle_10":           return profile.totalPuzzlesSolved >= 10
        case "puzzle_100":          return profile.totalPuzzlesSolved >= 100
        case "puzzle_500":          return profile.totalPuzzlesSolved >= 500
        case "first_session":       return profile.sessionsCompleted >= 1
        case "sessions_7":          return profile.sessionsCompleted >= 7
        case "sessions_30":         return profile.sessionsCompleted >= 30
        case "streak_3":            return streak >= 3
        case "streak_7":            return streak >= 7
        case "streak_30":           return streak >= 30
        case "tactics_master":      return profile.tacticsAccuracy >= 80
        case "opening_specialist":  return profile.openingAccuracy >= 75
        case "endgame_technician":  return profile.endgameAccuracy >= 75
        case "calculation_master":  return profile.calculationScore >= 80
        case "strategy_expert":     return profile.strategyScore >= 75
        case "elo_1000":            return profile.elo >= 1000
        case "elo_1200":            return profile.elo >= 1200
        case "elo_1500":            return profile.elo >= 1500
        case "elo_1800":            return profile.elo >= 1800
        default:                    return false
        }
    }

    static let allAchievements: [Achievement] = [
        // Puzzle achievements
        Achievement(id: "first_puzzle", title: "First Puzzle", description: "Solve your first puzzle", icon: "puzzle", category: .tactics, rarity: .common),
        Achievement(id: "puzzle_10", title: "Puzzle Enthusiast", description: "Solve 10 puzzles", icon: "puzzles_10", category: .tactics, rarity: .common),
        Achievement(id: "puzzle_100", title: "Tactical Vision", description: "Solve 100 puzzles", icon: "brain", category: .tactics, rarity: .uncommon),
        Achievement(id: "puzzle_500", title: "Tactics Machine", description: "Solve 500 puzzles", icon: "bolt.circle.fill", category: .tactics, rarity: .rare),

        // Session achievements
        Achievement(id: "first_session", title: "Training Begins", description: "Complete your first training session", icon: "play.fill", category: .training, rarity: .common),
        Achievement(id: "sessions_7", title: "Week Warrior", description: "Complete 7 training sessions", icon: "calendar.badge.clock", category: .training, rarity: .common),
        Achievement(id: "sessions_30", title: "Dedicated Student", description: "Complete 30 training sessions", icon: "star.fill", category: .training, rarity: .uncommon),

        // Streak achievements
        Achievement(id: "streak_3", title: "On Fire", description: "Train 3 days in a row", icon: "flame", category: .consistency, rarity: .common),
        Achievement(id: "streak_7", title: "Week Champion", description: "Train 7 days in a row", icon: "flame.fill", category: .consistency, rarity: .uncommon),
        Achievement(id: "streak_30", title: "Unstoppable", description: "Train 30 days in a row", icon: "bolt.fill", category: .consistency, rarity: .epic),

        // Skill achievements
        Achievement(id: "tactics_master", title: "Tactical Vision Upgrade", description: "Achieve 80% tactics accuracy", icon: "target", category: .tactics, rarity: .rare),
        Achievement(id: "opening_specialist", title: "Opening Specialist", description: "Achieve 75% opening accuracy", icon: "book.fill", category: .openings, rarity: .rare),
        Achievement(id: "endgame_technician", title: "Endgame Technician", description: "Achieve 75% endgame accuracy", icon: "flag.checkered", category: .endgames, rarity: .rare),
        Achievement(id: "calculation_master", title: "Calculation Master", description: "Achieve 80% calculation score", icon: "brain.head.profile", category: .calculation, rarity: .epic),
        Achievement(id: "strategy_expert", title: "Strategy Expert", description: "Achieve 75% strategy score", icon: "map.fill", category: .strategy, rarity: .rare),

        // Elo achievements
        Achievement(id: "elo_1000", title: "Four Digits", description: "Reach 1000 Elo", icon: "1.circle.fill", category: .rating, rarity: .common),
        Achievement(id: "elo_1200", title: "Club Player", description: "Reach 1200 Elo", icon: "2.circle.fill", category: .rating, rarity: .uncommon),
        Achievement(id: "elo_1500", title: "Intermediate", description: "Reach 1500 Elo", icon: "3.circle.fill", category: .rating, rarity: .rare),
        Achievement(id: "elo_1800", title: "Advanced Player", description: "Reach 1800 Elo", icon: "crown.fill", category: .rating, rarity: .epic)
    ]
}

enum AchievementCategory: String, Codable, CaseIterable {
    case tactics = "Tactics"
    case openings = "Openings"
    case endgames = "Endgames"
    case calculation = "Calculation"
    case strategy = "Strategy"
    case training = "Training"
    case consistency = "Consistency"
    case rating = "Rating"
}

enum AchievementRarity: String, Codable, CaseIterable {
    case common = "Common"
    case uncommon = "Uncommon"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"

    var color: String {
        switch self {
        case .common: return "gray"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "orange"
        }
    }
}
