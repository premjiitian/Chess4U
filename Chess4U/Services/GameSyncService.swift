import Foundation

// MARK: - Game Sync Service
/// Orchestrates the end-to-end "sync my recent games and build a puzzle book
/// from my mistakes" flow: fetch games from chess.com/Lichess for a chosen
/// window, analyze each one, extract mistakes/inaccuracies/blunders as
/// puzzles, and persist them for practice in "My Puzzles".
@MainActor
final class GameSyncService: ObservableObject {
    static let shared = GameSyncService()

    @Published var isSyncing: Bool = false
    @Published var progressText: String = ""
    @Published var lastSyncSummary: String?
    @Published var lastError: String?

    private let platformService = ExternalPlatformService.shared
    private let puzzleService = PersonalPuzzleService.shared
    private let persistence = PersistenceService.shared

    private init() {}

    /// Fetches every game played on `platform` by `username` in the last `days`
    /// days, analyzes each for mistakes, and saves any new puzzles found.
    /// Games already synced before (by ID) are skipped so re-running this
    /// doesn't re-analyze the same games every time.
    func syncRecentGames(platform: ExternalGame.Platform, username: String, days: Int = 30, profile: PlayerProfile?) async {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            lastError = "Enter your \(platform.rawValue) username first."
            return
        }

        isSyncing = true
        lastError = nil
        lastSyncSummary = nil
        progressText = "Fetching games from \(platform.rawValue)…"

        let effectiveProfile = profile ?? PlayerProfile(
            name: "Player", elo: 1000,
            preferredTimeControl: .rapid, playerType: .casual,
            mainOpeningsWhite: [], mainDefensesBlack: [],
            ratingTrend: .stable, weaknesses: [.tactics]
        )

        do {
            let allGames = try await platformService.fetchRecentGames(platform: platform, username: username, days: days)
            let alreadySynced = persistence.loadSyncedGameIDs()
            let newGames = allGames.filter { !alreadySynced.contains($0.id) }

            guard !newGames.isEmpty else {
                isSyncing = false
                progressText = ""
                lastSyncSummary = allGames.isEmpty
                    ? "No games found in the last \(days) days for \(username)."
                    : "No new games since your last sync — all \(allGames.count) recent games were already analyzed."
                return
            }

            progressText = "Analyzing \(newGames.count) game\(newGames.count == 1 ? "" : "s")…"

            // The per-move engine analysis (minimax to depth 2 for every move
            // of every game) is CPU-heavy -- run it off the main actor so the
            // sync progress UI stays responsive instead of freezing.
            let puzzleService = self.puzzleService
            let newPuzzles: [ChessPuzzle] = await Task.detached(priority: .userInitiated) {
                puzzleService.generatePuzzles(from: newGames, profile: effectiveProfile)
            }.value

            let addedCount = persistence.addPersonalPuzzles(newPuzzles)
            persistence.markGamesSynced(newGames.map { $0.id })

            isSyncing = false
            progressText = ""
            if addedCount > 0 {
                lastSyncSummary = "Synced \(newGames.count) new game\(newGames.count == 1 ? "" : "s") — found \(addedCount) new puzzle\(addedCount == 1 ? "" : "s") from your mistakes."
            } else {
                lastSyncSummary = "Synced \(newGames.count) new game\(newGames.count == 1 ? "" : "s") — no notable mistakes found. Nicely played!"
            }
        } catch {
            isSyncing = false
            progressText = ""
            lastError = error.localizedDescription
        }
    }
}
