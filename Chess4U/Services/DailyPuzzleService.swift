import Foundation

// MARK: - Daily Puzzle Service
/// Manages the "Puzzle of the Day" feature:
/// - Selects a puzzle deterministically by day-of-year so every user sees the same puzzle.
/// - Persists completion status and tracks a dedicated daily streak.
final class DailyPuzzleService: ObservableObject {
    static let shared = DailyPuzzleService()

    @Published var todaysPuzzle: ChessPuzzle?
    @Published var isCompleted: Bool = false
    @Published var streak: Int = 0
    @Published var bestTime: TimeInterval?

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let completionDate = "dailyPuzzle.completionDate"
        static let streak         = "dailyPuzzle.streak"
        static let bestTime       = "dailyPuzzle.bestTime"
        static let lastStreakDate  = "dailyPuzzle.lastStreakDate"
    }

    private init() {
        loadState()
        selectTodaysPuzzle()
    }

    private func selectTodaysPuzzle() {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let pool = ChessPuzzle.dailyPuzzlePool
        guard !pool.isEmpty else { return }
        todaysPuzzle = pool[dayOfYear % pool.count]
    }

    func markCompleted(timeSpent: TimeInterval) {
        isCompleted = true
        defaults.set(Date(), forKey: Keys.completionDate)
        if let best = bestTime {
            if timeSpent < best { bestTime = timeSpent; defaults.set(timeSpent, forKey: Keys.bestTime) }
        } else {
            bestTime = timeSpent; defaults.set(timeSpent, forKey: Keys.bestTime)
        }
        updateStreak()
    }

    private func updateStreak() {
        let calendar = Calendar.current
        if let lastDate = defaults.object(forKey: Keys.lastStreakDate) as? Date {
            let daysDiff = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            if daysDiff == 1 { streak += 1 } else if daysDiff > 1 { streak = 1 }
        } else { streak = 1 }
        defaults.set(streak, forKey: Keys.streak)
        defaults.set(Date(), forKey: Keys.lastStreakDate)
    }

    private func loadState() {
        streak = defaults.integer(forKey: Keys.streak)
        let savedBest = defaults.double(forKey: Keys.bestTime)
        bestTime = savedBest > 0 ? savedBest : nil
        if let completionDate = defaults.object(forKey: Keys.completionDate) as? Date {
            isCompleted = Calendar.current.isDateInToday(completionDate)
        }
    }
}

// MARK: - Daily Puzzle Pool
extension ChessPuzzle {
    static let dailyPuzzlePool: [ChessPuzzle] = [
        ChessPuzzle(fen: "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 4 4",
            solution: ["f3f7"], theme: .mateInOne, difficulty: .beginner, playerToMove: .white, rating: 700,
            title: "The Deadly f7 Attack",
            explanation: "Qxf7# checkmates immediately. The f7 square is only defended by the king.",
            hint: "Find the weakest square in Black's position"),
        ChessPuzzle(fen: "6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1",
            solution: ["d1d8"], theme: .backRankMate, difficulty: .easy, playerToMove: .white, rating: 800,
            title: "Back Rank Weakness",
            explanation: "Rd8# — Black's king is trapped by its own pawns. Always keep a luft!",
            hint: "The king's own pawns can be a prison"),
        ChessPuzzle(fen: "r1bqkb1r/pppp1ppp/2n2n2/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3",
            solution: ["f3e5"], theme: .fork, difficulty: .easy, playerToMove: .white, rating: 1050,
            title: "Central Knight Fork",
            explanation: "Nxe5 forks the c6-knight and wins material.",
            hint: "Knights love to fork — look for two undefended targets"),
        ChessPuzzle(fen: "rnb1kbnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR w KQkq - 0 4",
            solution: ["f1b5"], theme: .pin, difficulty: .easy, playerToMove: .white, rating: 1100,
            title: "Pin Against the King",
            explanation: "Bb5+ pins the c6-knight to the king — the knight cannot move.",
            hint: "A bishop check from a diagonal can pin a blocking piece"),
        ChessPuzzle(fen: "r2qkb1r/ppp2ppp/2n1pn2/3p4/3P1B2/2N1PN2/PPP2PPP/R2QKB1R w KQkq - 2 6",
            solution: ["f4d6"], theme: .discoveredAttack, difficulty: .medium, playerToMove: .white, rating: 1350,
            title: "Discovered Attack on the Queen",
            explanation: "Bxd6 wins the pawn AND discovers an attack on Black's queen from the d1-rook.",
            hint: "Move one piece to unleash a hidden attacker"),
        ChessPuzzle(fen: "r1b1kb1r/pppp1ppp/2n2n2/4p3/2B1P3/3P4/PPP2PPP/RNBQK1NR w KQkq - 0 4",
            solution: ["d1h5", "h5f7"], theme: .mateInTwo, difficulty: .medium, playerToMove: .white, rating: 1200,
            title: "Double Threat Forces Mate",
            explanation: "Qh5 threatens both Qxf7# and Qxe5. Black cannot defend both.",
            hint: "Create two threats that cannot both be stopped"),
        ChessPuzzle(fen: "8/4k3/8/3KP3/8/8/8/8 w - - 0 1",
            solution: ["d5e4", "e7e6", "e4f4", "e6f6", "e5e6"], theme: .endgameTechnique, difficulty: .hard, playerToMove: .white, rating: 1650,
            title: "Opposition in K+P Endgame",
            explanation: "Use the opposition: the king leads the pawn to victory.",
            hint: "In king-pawn endgames, the king must lead"),
        ChessPuzzle(fen: "r2q1rk1/pp2bppp/2np1n2/2p1p3/2B1P3/2N1BN2/PPP2PPP/R2Q1RK1 w - - 0 1",
            solution: ["c4f7", "f8f7", "d1d8"], theme: .queenSacrifice, difficulty: .hard, playerToMove: .white, rating: 1800,
            title: "Greek Gift Sacrifice",
            explanation: "Bxf7+ forces the king to take, then Qxd8 wins decisively.",
            hint: "Sacrificing on f7 often opens the king to a fatal attack"),
        ChessPuzzle(fen: "r4rk1/pp2ppbp/2n3p1/q7/3P4/2N2N2/PP2BPPP/R2QR1K1 w - - 0 1",
            solution: ["d4d5"], theme: .deflection, difficulty: .medium, playerToMove: .white, rating: 1500,
            title: "Pawn Deflects the Defender",
            explanation: "d5 forces the c6-knight away from its key defensive role.",
            hint: "Force a defender away from its post"),
        ChessPuzzle(fen: "r1bq1rk1/pp2ppbp/2np1np1/8/3NP3/2N1BP2/PPP3PP/R2QKB1R w KQ - 0 8",
            solution: ["d4f5"], theme: .middlegameTactics, difficulty: .hard, playerToMove: .white, rating: 1750,
            title: "Knight Outpost on f5",
            explanation: "Nf5 seizes an outpost that Black's pawns cannot attack. The knight dominates from here.",
            hint: "An outpost is a square where no enemy pawn can attack"),
        ChessPuzzle(fen: "8/8/p7/Pp6/1P1k4/8/1K6/8 w - - 0 1",
            solution: ["b2c2", "d4e4", "c2d2", "e4f4", "d2e2"], theme: .endgameTechnique, difficulty: .expert, playerToMove: .white, rating: 2000,
            title: "Pawn Endgame Zugzwang",
            explanation: "White maneuvers the king to create a zugzwang — Black's every move loses.",
            hint: "Put your opponent in a position where any move makes things worse"),
        ChessPuzzle(fen: "4k3/8/8/8/8/8/4P3/4K3 w - - 0 1",
            solution: ["e1d2", "e8d7", "d2e3", "d7e7", "e3f4", "e7f6", "e2e4", "f6e6", "f4e4"], theme: .endgameTechnique, difficulty: .expert, playerToMove: .white, rating: 1950,
            title: "Key Squares Concept",
            explanation: "White must reach d6/e6/f6 with the king before advancing the pawn.",
            hint: "Identify the key squares — controlling them wins the game"),
    ]
}
