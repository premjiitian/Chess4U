import Foundation

// MARK: - Training Type
enum TrainingType: String, Codable, CaseIterable {
    case tactics = "Tactics"
    case openings = "Openings"
    case middlegame = "Middlegame Strategy"
    case endgame = "Endgame"
    case calculation = "Calculation"
    case variationPractice = "Variation Practice"
    case gameAnalysis = "Game Analysis"
    case blunderReduction = "Blunder Reduction"

    var icon: String {
        switch self {
        case .tactics: return "bolt.fill"
        case .openings: return "book.fill"
        case .middlegame: return "map.fill"
        case .endgame: return "flag.checkered"
        case .calculation: return "brain"
        case .variationPractice: return "arrow.triangle.branch"
        case .gameAnalysis: return "magnifyingglass"
        case .blunderReduction: return "shield.fill"
        }
    }

    var color: String {
        switch self {
        case .tactics: return "yellow"
        case .openings: return "blue"
        case .middlegame: return "purple"
        case .endgame: return "green"
        case .calculation: return "orange"
        case .variationPractice: return "teal"
        case .gameAnalysis: return "indigo"
        case .blunderReduction: return "red"
        }
    }

    var estimatedMinutes: Int {
        switch self {
        case .tactics: return 15
        case .openings: return 20
        case .middlegame: return 25
        case .endgame: return 20
        case .calculation: return 30
        case .variationPractice: return 25
        case .gameAnalysis: return 20
        case .blunderReduction: return 15
        }
    }
}

// MARK: - Per-theme result within a single session
struct ThemeSessionResult: Codable {
    var attempts: Int = 0
    var solved: Int = 0
}

// MARK: - Training Session
struct TrainingSession: Codable, Identifiable {
    var id: UUID = UUID()
    var type: TrainingType
    var playerBand: PlayerBand
    var startDate: Date
    var endDate: Date?
    var puzzlesSolved: Int = 0
    var puzzlesAttempted: Int = 0
    var correctMoves: Int = 0
    var totalMoves: Int = 0
    var hintsUsed: Int = 0
    var conceptLesson: ConceptLesson?
    var warmupPuzzles: [ChessPuzzle] = []
    var mainPuzzles: [ChessPuzzle] = []
    var currentPuzzleIndex: Int = 0
    /// Per-theme puzzle results, keyed by PuzzleTheme.rawValue
    var themeResults: [String: ThemeSessionResult] = [:]

    var accuracy: Double {
        guard totalMoves > 0 else { return 0 }
        return Double(correctMoves) / Double(totalMoves) * 100
    }

    var puzzleAccuracy: Double {
        guard puzzlesAttempted > 0 else { return 0 }
        return Double(puzzlesSolved) / Double(puzzlesAttempted) * 100
    }

    var isComplete: Bool { endDate != nil }
    var duration: TimeInterval? {
        guard let end = endDate else { return nil }
        return end.timeIntervalSince(startDate)
    }
}

// MARK: - Concept Lesson
struct ConceptLesson: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var concept: String
    var explanation: String
    var example: String
    var keyIdea: String
    var commonMistake: String
    var howStrongPlayersUseIt: String
    var fen: String?
    var type: TrainingType
    var playerBand: PlayerBand
    var audioScript: String?

    static func lesson(for type: TrainingType, band: PlayerBand) -> ConceptLesson {
        ConceptLesson.lessonDatabase[type]?[band] ?? ConceptLesson.defaultLesson(type: type, band: band)
    }

    static func defaultLesson(type: TrainingType, band: PlayerBand) -> ConceptLesson {
        ConceptLesson(
            title: "Chess Fundamentals",
            concept: "Piece Activity",
            explanation: "Active pieces are the key to good chess. Always try to place your pieces on squares where they have maximum influence.",
            example: "A knight on f5 attacks h6, g7, e7, d6, d4, e3, g3, h4 — 8 squares!",
            keyIdea: "Place pieces on their optimal squares.",
            commonMistake: "Leaving pieces passive and undeveloped.",
            howStrongPlayersUseIt: "GMs constantly improve their worst-placed piece.",
            type: type,
            playerBand: band
        )
    }

    static let lessonDatabase: [TrainingType: [PlayerBand: ConceptLesson]] = {
        var db: [TrainingType: [PlayerBand: ConceptLesson]] = [:]

        // Tactics lessons
        db[.tactics] = [
            .bandA: ConceptLesson(
                title: "Forks — Double Attack",
                concept: "Fork",
                explanation: "A fork attacks two pieces at once. Knights are especially powerful forkers.",
                example: "Knight on c7 attacks King on a8 and Rook on e8 simultaneously.",
                keyIdea: "Look for moves that attack two things at once.",
                commonMistake: "Missing fork opportunities because you don't check all knight moves.",
                howStrongPlayersUseIt: "GMs constantly look for knight forks and create conditions for them.",
                type: .tactics, playerBand: .bandA,
                audioScript: "A fork is one of the most powerful tactics in chess. When your piece attacks two enemy pieces at the same time, your opponent can only save one."
            ),
            .bandB: ConceptLesson(
                title: "Pins and Skewers",
                concept: "Pin",
                explanation: "A pin restricts a piece from moving because it would expose a more valuable piece behind it.",
                example: "Bishop on b5 pins the knight on c6 to the king on e8.",
                keyIdea: "Pinned pieces cannot move without exposing something valuable.",
                commonMistake: "Forgetting that pinned pieces can still capture and be dangerous.",
                howStrongPlayersUseIt: "Creating pins to restrict opponent's pieces and win material.",
                type: .tactics, playerBand: .bandB,
                audioScript: "Pins are positional weapons that restrict your opponent's freedom. A pinned piece is like a paralyzed soldier."
            ),
            .bandC: ConceptLesson(
                title: "Deflection and Decoy",
                concept: "Deflection",
                explanation: "Force an opponent's piece away from a key defensive duty.",
                example: "Sacrifice on h7 to deflect the king from defending e7.",
                keyIdea: "Identify overloaded pieces and deflect them.",
                commonMistake: "Missing deflection opportunities in complex positions.",
                howStrongPlayersUseIt: "Use deflection to exploit overloaded defenders.",
                type: .tactics, playerBand: .bandC,
                audioScript: "Deflection is the art of forcing enemy pieces away from their duties. Find the overloaded defender and attack it."
            )
        ]

        // Opening lessons
        db[.openings] = [
            .bandA: ConceptLesson(
                title: "Opening Principles",
                concept: "Opening Fundamentals",
                explanation: "Control the center, develop pieces, and castle early. These three principles guide every opening.",
                example: "1.e4 e5 2.Nf3 Nc6 3.Bc4 — classic development and center control.",
                keyIdea: "Develop with purpose: center control and king safety.",
                commonMistake: "Moving the same piece twice in the opening.",
                howStrongPlayersUseIt: "Every move serves multiple purposes: development, center control, or king safety.",
                type: .openings, playerBand: .bandA,
                audioScript: "The opening is about getting your pieces into the game. Control the center squares e4, e5, d4, d5 and develop your pieces quickly."
            ),
            .bandB: ConceptLesson(
                title: "Understanding Pawn Structures",
                concept: "Pawn Structure",
                explanation: "Your pawns determine your long-term strategy. Different pawn structures call for different plans.",
                example: "Isolated queen's pawn: active piece play vs. blockade.",
                keyIdea: "Identify your pawn structure and find the plan that suits it.",
                commonMistake: "Playing without a plan based on pawn structure.",
                howStrongPlayersUseIt: "Every GM knows the typical plans for each pawn formation.",
                type: .openings, playerBand: .bandB
            )
        ]

        // Endgame lessons
        db[.endgame] = [
            .bandA: ConceptLesson(
                title: "King Activity in Endgames",
                concept: "Active King",
                explanation: "In the endgame, the king becomes a powerful piece. Activate it immediately.",
                example: "King march to e4 in a pawn endgame to support your passed pawn.",
                keyIdea: "Activate your king the moment queens come off the board.",
                commonMistake: "Keeping the king passive in endgames.",
                howStrongPlayersUseIt: "GMs immediately centralize the king when queens are exchanged.",
                type: .endgame, playerBand: .bandA,
                audioScript: "In the endgame, your king is not just a liability — it's a weapon. March it to the center and use it aggressively."
            ),
            .bandB: ConceptLesson(
                title: "Rook Endgames — Active Rook",
                concept: "Rook Activity",
                explanation: "Rooks belong behind passed pawns — yours or your opponent's.",
                example: "Place your rook on the 7th rank to cut off the enemy king and attack pawns.",
                keyIdea: "Rooks are most powerful on open files and behind passed pawns.",
                commonMistake: "Placing rooks passively in endgames.",
                howStrongPlayersUseIt: "Philidor position, Lucena position — every GM knows key rook endings.",
                type: .endgame, playerBand: .bandB
            )
        ]

        return db
    }()
}

// MARK: - Weekly Training Plan
struct WeeklyTrainingPlan: Codable {
    var weekNumber: Int
    var playerBand: PlayerBand
    var dailyPlans: [DailyPlan]
    var generatedDate: Date

    static func generate(for profile: PlayerProfile) -> WeeklyTrainingPlan {
        let band = profile.band
        let plans = TreeOfThoughtEngine.shared.generateWeeklyPlan(for: profile)
        return WeeklyTrainingPlan(
            weekNumber: Calendar.current.component(.weekOfYear, from: Date()),
            playerBand: band,
            dailyPlans: plans,
            generatedDate: Date()
        )
    }
}

struct DailyPlan: Codable, Identifiable {
    var id: UUID = UUID()
    var dayOfWeek: String
    var dayNumber: Int
    var trainingTypes: [TrainingType]
    var focusDescription: String
    var estimatedMinutes: Int
    var isCompleted: Bool = false

    var totalMinutes: Int { trainingTypes.reduce(0) { $0 + $1.estimatedMinutes } }
}
