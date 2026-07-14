import Foundation
import WidgetKit

// MARK: - Persistence Service
final class PersistenceService {
    static let shared = PersistenceService()
    private let defaults = UserDefaults.standard
    /// Shared suite for WidgetKit — must match the App Group entitlement.
    private let sharedDefaults = UserDefaults(suiteName: "group.com.chess4u.app") ?? .standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let playerProfile = "chess4u.playerProfile"
        static let settings = "chess4u.settings"
        static let achievements = "chess4u.achievements"
        static let streak = "chess4u.streak"
        static let lastSessionDate = "chess4u.lastSessionDate"
        static let sessionHistory = "chess4u.sessionHistory"
        static let savedGames = "chess4u.savedGames"
        static let openingMastery = "chess4u.openingMastery"
        static let personalPuzzles = "chess4u.personalPuzzles"
        static let syncedGameIDs = "chess4u.syncedGameIDs"
    }

    // MARK: - Player Profile
    func savePlayerProfile(_ profile: PlayerProfile) {
        if let data = try? encoder.encode(profile) {
            defaults.set(data, forKey: Keys.playerProfile)
        }
        // Mirror lightweight fields to shared suite for the widget
        sharedDefaults.set(profile.name, forKey: "chess4u.playerName")
        sharedDefaults.set(profile.elo,  forKey: "chess4u.elo")
    }

    func loadPlayerProfile() -> PlayerProfile? {
        guard let data = defaults.data(forKey: Keys.playerProfile) else { return nil }
        return try? decoder.decode(PlayerProfile.self, from: data)
    }

    // MARK: - Settings
    func saveSettings(_ settings: AppSettings) {
        if let data = try? encoder.encode(settings) {
            defaults.set(data, forKey: Keys.settings)
        }
    }

    func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: Keys.settings),
              let settings = try? decoder.decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    // MARK: - Achievements
    func saveAchievements(_ achievements: [Achievement]) {
        if let data = try? encoder.encode(achievements) {
            defaults.set(data, forKey: Keys.achievements)
        }
    }

    func loadAchievements() -> [Achievement] {
        guard let data = defaults.data(forKey: Keys.achievements),
              let achievements = try? decoder.decode([Achievement].self, from: data) else {
            return []
        }
        return achievements
    }

    // MARK: - Training Streak
    func saveStreak(_ streak: Int) {
        defaults.set(streak, forKey: Keys.streak)
        defaults.set(Date(), forKey: Keys.lastSessionDate)
        // Mirror to shared suite so the widget shows the latest streak
        sharedDefaults.set(streak, forKey: "chess4u.streak")
        sharedDefaults.set(Date(), forKey: "chess4u.lastSessionDate")
        WidgetCenter.shared.reloadTimelines(ofKind: "Chess4UStreakWidget")
    }

    func loadStreak() -> Int {
        guard let lastDate = defaults.object(forKey: Keys.lastSessionDate) as? Date else {
            return 0
        }
        let daysSinceLast = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        if daysSinceLast > 1 {
            defaults.set(0, forKey: Keys.streak)
            return 0
        }
        return defaults.integer(forKey: Keys.streak)
    }

    // MARK: - Session History
    func saveSessionHistory(_ sessions: [TrainingSession]) {
        let recent = Array(sessions.suffix(100))
        if let data = try? encoder.encode(recent) {
            defaults.set(data, forKey: Keys.sessionHistory)
        }
        // Count today's sessions for the widget progress bar
        let todayCount = recent.filter {
            guard let end = $0.endDate else { return false }
            return Calendar.current.isDateInToday(end)
        }.count
        sharedDefaults.set(todayCount, forKey: "chess4u.todaySessionsDone")
    }

    func saveWidgetGoal(_ goal: Int) {
        sharedDefaults.set(goal, forKey: "chess4u.todaySessionsGoal")
    }

    func loadSessionHistory() -> [TrainingSession] {
        guard let data = defaults.data(forKey: Keys.sessionHistory),
              let sessions = try? decoder.decode([TrainingSession].self, from: data) else {
            return []
        }
        return sessions
    }

    // MARK: - Saved Games
    func saveGame(_ game: ChessGame) {
        var games = loadSavedGames()
        games.append(game)
        if let data = try? encoder.encode(games) {
            defaults.set(data, forKey: Keys.savedGames)
        }
    }

    func loadSavedGames() -> [ChessGame] {
        guard let data = defaults.data(forKey: Keys.savedGames),
              let games = try? decoder.decode([ChessGame].self, from: data) else {
            return []
        }
        return games
    }

    // MARK: - Personal Puzzles (auto-generated from imported games)
    /// Puzzles are stored newest-first and capped so the list can't grow
    /// unbounded after repeated syncs.
    private let maxPersonalPuzzles = 300

    func savePersonalPuzzles(_ puzzles: [ChessPuzzle]) {
        if let data = try? encoder.encode(puzzles) {
            defaults.set(data, forKey: Keys.personalPuzzles)
        }
    }

    func loadPersonalPuzzles() -> [ChessPuzzle] {
        guard let data = defaults.data(forKey: Keys.personalPuzzles),
              let puzzles = try? decoder.decode([ChessPuzzle].self, from: data) else {
            return []
        }
        return puzzles
    }

    /// Merges newly generated puzzles into the saved collection, skipping any
    /// whose FEN we already have (avoids duplicates when the same game is
    /// synced twice), and returns how many were actually new.
    @discardableResult
    func addPersonalPuzzles(_ newPuzzles: [ChessPuzzle]) -> Int {
        var existing = loadPersonalPuzzles()
        let existingFENs = Set(existing.map { $0.fen })
        let trulyNew = newPuzzles.filter { !existingFENs.contains($0.fen) }
        existing.insert(contentsOf: trulyNew, at: 0)
        if existing.count > maxPersonalPuzzles {
            existing = Array(existing.prefix(maxPersonalPuzzles))
        }
        savePersonalPuzzles(existing)
        return trulyNew.count
    }

    /// Removes specific puzzles from the personal collection by id (used by
    /// My Puzzles' swipe-to-delete).
    func deletePersonalPuzzles(ids: [UUID]) {
        var existing = loadPersonalPuzzles()
        let idSet = Set(ids)
        existing.removeAll { idSet.contains($0.id) }
        savePersonalPuzzles(existing)
    }

    /// IDs of external games (chess.com/Lichess) already analyzed, so a
    /// repeat "sync last 30 days" doesn't re-analyze the same games.
    func loadSyncedGameIDs() -> Set<String> {
        guard let ids = defaults.stringArray(forKey: Keys.syncedGameIDs) else { return [] }
        return Set(ids)
    }

    func markGamesSynced(_ ids: [String]) {
        var all = loadSyncedGameIDs()
        all.formUnion(ids)
        defaults.set(Array(all), forKey: Keys.syncedGameIDs)
    }

    // MARK: - Reset
    func resetAllData() {
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
    }
}
