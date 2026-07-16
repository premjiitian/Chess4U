import Foundation

// MARK: - Puzzle Difficulty
enum PuzzleDifficulty: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case expert = "Expert"

    var eloRange: ClosedRange<Int> {
        switch self {
        case .beginner: return 800...1000
        case .easy:     return 1000...1300
        case .medium:   return 1300...1600
        case .hard:     return 1600...1800
        case .expert:   return 1800...2200
        }
    }
}

// MARK: - Puzzle Theme
enum PuzzleTheme: String, Codable, CaseIterable {
    case fork = "Fork"
    case pin = "Pin"
    case skewer = "Skewer"
    case discoveredAttack = "Discovered Attack"
    case doubleCheck = "Double Check"
    case backRankMate = "Back Rank Mate"
    case smotheredMate = "Smothered Mate"
    case queenSacrifice = "Queen Sacrifice"
    case deflection = "Deflection"
    case decoy = "Decoy"
    case xRayAttack = "X-Ray Attack"
    case zugzwang = "Zugzwang"
    case passedPawn = "Passed Pawn"
    case mateInOne = "Mate in 1"
    case mateInTwo = "Mate in 2"
    case mateInThree = "Mate in 3"
    case endgameTechnique = "Endgame Technique"
    case openingTrap = "Opening Trap"
    case middlegameTactics = "Middlegame Tactics"
    case combination = "Combination"
    /// Auto-generated from the player's own imported chess.com/Lichess games
    /// (see PersonalPuzzleService) -- distinguishes "your mistakes" puzzles
    /// from the curated database in the UI.
    case personalMistake = "From Your Games"
    /// A position the player deliberately bookmarked while reviewing an
    /// imported game (see GameAnalysisView's "Save Position" button), as
    /// opposed to one auto-detected from a mistake.
    case personalBookmark = "Saved From Game"

    var icon: String {
        switch self {
        case .fork: return "⑂"
        case .pin: return "📌"
        case .skewer: return "⚔️"
        case .discoveredAttack: return "💥"
        case .doubleCheck: return "⚡"
        case .backRankMate: return "🏠"
        case .smotheredMate: return "🤝"
        case .queenSacrifice: return "♛"
        case .deflection: return "↗️"
        case .decoy: return "🎯"
        case .xRayAttack: return "🔍"
        case .zugzwang: return "😰"
        case .passedPawn: return "♟"
        case .mateInOne: return "1️⃣"
        case .mateInTwo: return "2️⃣"
        case .mateInThree: return "3️⃣"
        case .endgameTechnique: return "🏁"
        case .openingTrap: return "🪤"
        case .middlegameTactics: return "⚡"
        case .combination: return "🌟"
        case .personalMistake: return "🧩"
        case .personalBookmark: return "⭐"
        }
    }
}

// MARK: - Chess Puzzle
struct ChessPuzzle: Codable, Identifiable {
    var id: UUID = UUID()
    var fen: String
    var solution: [String]          // Moves in long algebraic notation
    var theme: PuzzleTheme
    var difficulty: PuzzleDifficulty
    var playerToMove: PieceColor
    var rating: Int
    var title: String
    var explanation: String
    var hint: String?
    var followUpPositions: [String]?  // FENs after each solution move

    // Personal puzzle provenance -- nil for the built-in curated database,
    // populated for puzzles auto-generated from the player's own games.
    var sourcePlatform: String? = nil
    var sourceGameID: String? = nil
    var sourceDate: Date? = nil
    /// Both players' ratings at the time the source game was played, shown
    /// alongside the date on personal puzzles for context.
    var sourceWhiteRating: Int? = nil
    var sourceBlackRating: Int? = nil
    var sourceWhitePlayer: String? = nil
    var sourceBlackPlayer: String? = nil

    // Tracking
    var attemptCount: Int = 0
    var solvedCorrectly: Bool = false
    var timeSpent: TimeInterval = 0
    var hintsUsed: Int = 0

    static func warmupPuzzles(for band: PlayerBand) -> [ChessPuzzle] {
        puzzleDatabase.filter { p in
            band.calculationDepth.contains(p.solution.count - 1) &&
            (p.difficulty.eloRange.lowerBound >= (band == .bandA ? 800 : 1000))
        }.shuffled().prefix(5).map { $0 }
    }

    /// Every authored puzzle -- the base database plus the daily-puzzle pool,
    /// deduplicated by position. Training sessions draw from this combined
    /// pool so the same handful of puzzles doesn't repeat every session.
    static let fullDatabase: [ChessPuzzle] = {
        var seenFENs = Set<String>()
        return (puzzleDatabase + dailyPuzzlePool).filter { seenFENs.insert($0.fen).inserted }
    }()

    // Sample puzzle database
    static let puzzleDatabase: [ChessPuzzle] = [
        ChessPuzzle(
            fen: "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
            solution: ["f3g5", "d7d5", "e4d5", "f6d5", "g5f7"],
            theme: .fork,
            difficulty: .medium,
            playerToMove: .white,
            rating: 1400,
            title: "The Fried Liver Attack",
            explanation: "Ng5 attacks f7 twice. After the standard ...d5 exd5 Nxd5, the knight sacrifice Nxf7! forks queen and rook and drags Black's king into the open.",
            hint: "f7 is defended only by the king — attack it again."
        ),
        ChessPuzzle(
            fen: "6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1",
            solution: ["e1e8"],
            theme: .backRankMate,
            difficulty: .easy,
            playerToMove: .white,
            rating: 800,
            title: "Back Rank Mate",
            explanation: "White delivers checkmate immediately by moving the rook to e8. Black's king is trapped on the back rank.",
            hint: "Can you find a rook move that delivers checkmate?"
        ),
        ChessPuzzle(
            fen: "5rk1/p5pp/8/6N1/8/8/2Q4P/7K w - - 0 1",
            solution: ["c2b3", "g8h8", "g5f7", "h8g8", "f7h6", "g8h8", "b3g8", "f8g8", "h6f7"],
            theme: .queenSacrifice,
            difficulty: .hard,
            playerToMove: .white,
            rating: 1800,
            title: "Philidor's Legacy — Smothered Mate",
            explanation: "Qb3+ forces the king to the corner, the knight double-checks, and then Qg8+!! forces Rxg8 — leaving Nf7# with the king smothered by its own pieces.",
            hint: "A check on the long diagonal starts a famous forced sequence."
        ),
        ChessPuzzle(
            fen: "8/8/8/3k4/8/3K4/3P4/8 w - - 0 1",
            solution: ["d3e3", "d5e5", "d2d4", "e5d5", "e3d3"],
            theme: .endgameTechnique,
            difficulty: .medium,
            playerToMove: .white,
            rating: 1200,
            title: "Opposition in King and Pawn Endgame",
            explanation: "White uses the concept of opposition to advance the pawn. By taking the opposition, the white king forces the black king away.",
            hint: "Think about the concept of opposition between the kings."
        ),
        ChessPuzzle(
            fen: "r1bq1rk1/ppp2ppp/2np1n2/2b1p3/2B1P3/2NP1N2/PPP2PPP/R1BQ1RK1 w - - 0 1",
            solution: ["c4b5", "c6b8", "c3d5"],
            theme: .pin,
            difficulty: .medium,
            playerToMove: .white,
            rating: 1350,
            title: "Pin and Win",
            explanation: "The bishop move to b5 creates a pin on the knight. Then the knight jumps to d5 exploiting the pin.",
            hint: "How can you pin a knight?"
        ),
        ChessPuzzle(
            fen: "r1b1k2r/ppppqppp/2n2n2/2b1p3/2B1P3/2N2N2/PPPPQPPP/R1B1K2R w KQkq - 0 1",
            solution: ["c3d5", "f6d5", "c4d5"],
            theme: .fork,
            difficulty: .easy,
            playerToMove: .white,
            rating: 1100,
            title: "Knight Fork After Exchange",
            explanation: "The knight jump to d5 forks the knight on f6 and the bishop on c7, winning material.",
            hint: "Can a knight move attack two pieces at once?"
        ),
        ChessPuzzle(
            fen: "3r2k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1",
            solution: ["d1d8"],
            theme: .backRankMate,
            difficulty: .beginner,
            playerToMove: .white,
            rating: 700,
            title: "Winning the Back-Rank Defender",
            explanation: "Rxd8# — Black's rook was the only piece guarding the back rank, and nothing can recapture. Count defenders, not just attackers.",
            hint: "Black's rook is the only defender of d8. What if it disappears?"
        ),
        ChessPuzzle(
            fen: "2r3k1/5ppp/8/8/8/8/5PPP/2R3K1 w - - 0 1",
            solution: ["c1c8"],
            theme: .backRankMate,
            difficulty: .beginner,
            playerToMove: .white,
            rating: 750,
            title: "Rook vs Rook Back Rank",
            explanation: "White's rook checkmates by going to c8, exploiting the weak back rank.",
            hint: "Which file is open for a back rank attack?"
        ),
        ChessPuzzle(
            fen: "r1bqkb1r/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3",
            solution: ["f1c4", "f8c5", "c2c3", "d8f6"],
            theme: .openingTrap,
            difficulty: .easy,
            playerToMove: .white,
            rating: 1000,
            title: "Italian Game — Center Control",
            explanation: "White develops with Bc4 targeting f7, then plays c3 to prepare d4. Classical Italian development.",
            hint: "Develop pieces toward the center and prepare the pawn break."
        ),
        ChessPuzzle(
            fen: "4k3/8/8/8/8/8/4P3/4K3 w - - 0 1",
            solution: ["e1f2", "e8f8", "f2e3", "f8e7", "e3f3", "e7d7", "f3f4", "d7e7", "f4e5"],
            theme: .endgameTechnique,
            difficulty: .hard,
            playerToMove: .white,
            rating: 1600,
            title: "King and Pawn vs King — Winning Technique",
            explanation: "The king marches up the board AHEAD of its pawn. Once it reaches e5 in front of the pawn, the win is guaranteed — the pawn only advances once the king has cleared the road. (Engine-verified line.)",
            hint: "Move the king up the board first — the pawn can wait."
        )
    ]
}
