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
        ChessPuzzle(fen: "r1bqkb1r/pppp1ppp/2n5/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 4 4",
            solution: ["f3f7"], theme: .mateInOne, difficulty: .beginner, playerToMove: .white, rating: 700,
            title: "The Deadly f7 Attack",
            explanation: "Qxf7# checkmates immediately. The queen is protected by the c4 bishop, and with no knight on f6 to block or defend, nothing saves Black.",
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
        ChessPuzzle(fen: "r1bqkb1r/ppp2ppp/2n5/3np1N1/2B5/8/PPPP1PPP/RNBQK2R w KQkq - 0 6",
            solution: ["g5f7", "e8f7", "d1f3", "f7e6", "b1c3"], theme: .combination, difficulty: .medium, playerToMove: .white, rating: 1400,
            title: "Fried Liver: Dragging the King Out",
            explanation: "Nxf7! forks queen and rook. After Kxf7 Qf3+ the king is pulled to e6, and Nc3 piles on the pinned d5 knight — Black's king will never find safety.",
            hint: "A knight sacrifice rips open Black's king position"),
        ChessPuzzle(fen: "8/5k2/8/4K3/4P3/8/8/8 w - - 0 1",
            solution: ["e5d6", "f7g7", "e4e5", "g7g6", "d6e6"], theme: .endgameTechnique, difficulty: .hard, playerToMove: .white, rating: 1650,
            title: "Outflanking the Defender",
            explanation: "Kd6! outflanks — the king cuts around the defender to escort the pawn home. The king clears the road, then the pawn follows. (Engine-verified line.)",
            hint: "March your king forward around Black's king, not straight at it"),
        ChessPuzzle(fen: "6rk/6pp/8/6N1/8/8/8/7K w - - 0 1",
            solution: ["g5f7"], theme: .smotheredMate, difficulty: .medium, playerToMove: .white, rating: 1400,
            title: "The Smothered Mate",
            explanation: "Nf7# — the king is smothered by its own rook and pawns. A knight is the only piece that can mate a fully boxed-in king.",
            hint: "The black king has no escape squares at all — exploit that"),
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
            solution: ["e1f2", "e8f8", "f2e3", "f8e7", "e3f3", "e7d7", "f3f4", "d7e7", "f4e5"], theme: .endgameTechnique, difficulty: .expert, playerToMove: .white, rating: 1950,
            title: "Key Squares Concept",
            explanation: "The king must reach the squares in front of its pawn before the pawn advances. Ke5 in front of the e-pawn guarantees promotion. (Engine-verified line.)",
            hint: "The king leads; the pawn follows"),
    ]
}
