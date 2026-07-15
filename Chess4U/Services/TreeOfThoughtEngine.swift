import Foundation

// MARK: - Tree-of-Thought Training Decision Engine
final class TreeOfThoughtEngine {
    static let shared = TreeOfThoughtEngine()
    private init() {}

    // MARK: - Select Optimal Training Path
    func selectTrainingPath(for profile: PlayerProfile, sessionHistory: [TrainingSession]) -> TrainingType {
        // Step 1: Generate candidate training options
        var candidates: [(TrainingType, Double)] = TrainingType.allCases.map { type in
            (type, score(type: type, profile: profile, sessionHistory: sessionHistory))
        }

        // Step 3: Evaluate using improvement impact, engagement, fatigue risk, weakness targeting
        candidates.sort { $0.1 > $1.1 }

        // Step 4: Select optimal training path (highest scoring)
        return candidates.first?.0 ?? .tactics
    }

    private func score(type: TrainingType, profile: PlayerProfile, sessionHistory: [TrainingSession]) -> Double {
        var score: Double = 50.0

        // Weakness targeting bonus
        switch type {
        case .tactics:
            if profile.weaknesses.contains(.tactics) { score += 30 }
            if profile.weaknesses.contains(.blunders) { score += 20 }
            score += max(0, 80 - profile.tacticsAccuracy) * 0.3
        case .openings:
            if profile.weaknesses.contains(.openings) { score += 30 }
            score += max(0, 80 - profile.openingAccuracy) * 0.3
        case .endgame:
            if profile.weaknesses.contains(.endgames) { score += 30 }
            score += max(0, 80 - profile.endgameAccuracy) * 0.3
        case .calculation:
            if profile.weaknesses.contains(.calculation) { score += 30 }
            score += max(0, 80 - profile.calculationScore) * 0.3
        case .middlegame:
            if profile.weaknesses.contains(.strategy) { score += 25 }
            score += max(0, 80 - profile.strategyScore) * 0.25
        case .blunderReduction:
            if profile.weaknesses.contains(.blunders) { score += 35 }
        case .variationPractice:
            if profile.weaknesses.contains(.calculation) { score += 20 }
        case .gameAnalysis:
            score += 15 // Always valuable
        }

        // Fatigue avoidance — reduce score if same type done recently
        let recentSessions = Array(sessionHistory.suffix(3))
        let consecutiveSame = recentSessions.filter { $0.type == type }.count
        score -= Double(consecutiveSame) * 15

        // Band-specific bonuses
        switch profile.band {
        case .bandA:
            if type == .tactics || type == .blunderReduction { score += 20 }
        case .bandB:
            if type == .tactics || type == .openings { score += 15 }
        case .bandC:
            if type == .calculation || type == .middlegame { score += 15 }
        case .bandD:
            if type == .variationPractice || type == .endgame { score += 15 }
        case .bandE:
            if type == .calculation || type == .gameAnalysis { score += 20 }
        }

        return max(0, score)
    }

    // MARK: - Generate Weekly Plan
    func generateWeeklyPlan(for profile: PlayerProfile) -> [DailyPlan] {
        let band = profile.band
        var plans: [DailyPlan] = []

        let weekSchedule: [(String, [TrainingType], String)] = weekSchedule(for: band)

        for (idx, (day, types, focus)) in weekSchedule.enumerated() {
            let plan = DailyPlan(
                dayOfWeek: day,
                dayNumber: idx + 1,
                trainingTypes: types,
                focusDescription: focus,
                estimatedMinutes: types.reduce(0) { $0 + $1.estimatedMinutes }
            )
            plans.append(plan)
        }

        return plans
    }

    private func weekSchedule(for band: PlayerBand) -> [(String, [TrainingType], String)] {
        switch band {
        case .bandA:
            return [
                ("Monday", [.tactics, .blunderReduction], "Tactical Vision & Blunder Prevention"),
                ("Tuesday", [.openings], "Opening Principles"),
                ("Wednesday", [.tactics, .endgame], "Tactics + Basic Endgames"),
                ("Thursday", [.blunderReduction, .middlegame], "Board Vision & Simple Plans"),
                ("Friday", [.variationPractice], "Practice Games"),
                ("Saturday", [.endgame, .tactics], "Endgame Basics"),
                ("Sunday", [.gameAnalysis], "Review & Analysis")
            ]
        case .bandB:
            return [
                ("Monday", [.openings], "Opening Variations"),
                ("Tuesday", [.tactics], "Tactical Patterns"),
                ("Wednesday", [.middlegame, .calculation], "Strategy + Calculation"),
                ("Thursday", [.calculation], "Calculation Training"),
                ("Friday", [.variationPractice], "Practice Games"),
                ("Saturday", [.endgame], "Endgame Training"),
                ("Sunday", [.gameAnalysis], "Review & Analysis")
            ]
        case .bandC:
            return [
                ("Monday", [.openings], "Opening Deep Dive"),
                ("Tuesday", [.tactics], "Tactical Patterns"),
                ("Wednesday", [.middlegame], "Strategic Planning"),
                ("Thursday", [.calculation], "Calculation Bootcamp"),
                ("Friday", [.variationPractice], "Variation Practice"),
                ("Saturday", [.endgame], "Endgame Technique"),
                ("Sunday", [.gameAnalysis], "Game Analysis")
            ]
        case .bandD:
            return [
                ("Monday", [.openings, .variationPractice], "Opening Preparation"),
                ("Tuesday", [.tactics, .calculation], "Tactics + Calculation"),
                ("Wednesday", [.middlegame], "Advanced Strategy"),
                ("Thursday", [.calculation, .endgame], "Deep Calculation"),
                ("Friday", [.variationPractice], "Variation Drills"),
                ("Saturday", [.endgame], "Endgame Conversion"),
                ("Sunday", [.gameAnalysis], "Deep Analysis")
            ]
        case .bandE:
            return [
                ("Monday", [.openings, .calculation], "Deep Opening Prep"),
                ("Tuesday", [.tactics], "Complex Tactics"),
                ("Wednesday", [.middlegame, .calculation], "Master-Level Strategy"),
                ("Thursday", [.calculation], "Calculation Bootcamp"),
                ("Friday", [.variationPractice], "Opponent Simulation"),
                ("Saturday", [.endgame], "Technical Conversion"),
                ("Sunday", [.gameAnalysis], "Comprehensive Analysis")
            ]
        }
    }

    // MARK: - Generate Training Session
    func generateSession(type: TrainingType, profile: PlayerProfile,
                         difficulty: PuzzleDifficulty? = nil,
                         weakThemes: [PuzzleTheme] = []) -> TrainingSession {
        let band = profile.band
        var session = TrainingSession(type: type, playerBand: band, startDate: Date())

        session.warmupPuzzles = generateWarmupPuzzles(for: band, difficulty: difficulty)
        session.conceptLesson = ConceptLesson.lesson(for: type, band: band)
        session.mainPuzzles = generateMainPuzzles(type: type, band: band, count: 5,
                                                  difficulty: difficulty, weakThemes: weakThemes)
        return session
    }

    private func generateWarmupPuzzles(for band: PlayerBand, difficulty: PuzzleDifficulty? = nil) -> [ChessPuzzle] {
        let targetDifficulty: PuzzleDifficulty = difficulty ?? {
            switch band {
            case .bandA: return .beginner
            case .bandB: return .easy
            case .bandC: return .medium
            case .bandD: return .hard
            case .bandE: return .expert
            }
        }()
        let filtered = ChessPuzzle.fullDatabase.filter { $0.difficulty == targetDifficulty }
        // Fallback to any difficulty if not enough puzzles
        let pool = filtered.isEmpty ? ChessPuzzle.fullDatabase : filtered
        return pool.shuffled().prefix(3).map { $0 }
    }

    private func generateMainPuzzles(type: TrainingType, band: PlayerBand, count: Int,
                                     difficulty: PuzzleDifficulty? = nil,
                                     weakThemes: [PuzzleTheme] = []) -> [ChessPuzzle] {
        let baseThemes: [PuzzleTheme]
        switch type {
        case .tactics:
            baseThemes = [.fork, .pin, .skewer, .discoveredAttack, .doubleCheck, .deflection, .combination]
        case .endgame:
            baseThemes = [.endgameTechnique, .passedPawn, .zugzwang]
        case .openings:
            baseThemes = [.openingTrap]
        case .blunderReduction:
            baseThemes = [.backRankMate, .mateInOne, .mateInTwo]
        default:
            baseThemes = [.middlegameTactics, .combination, .fork]
        }

        // Include known weak themes from this training type (up to 2 extra weak-theme slots)
        let relevantWeakThemes = weakThemes.filter { baseThemes.contains($0) }.prefix(2)
        let priorityThemes = Array(relevantWeakThemes) + baseThemes

        let db = ChessPuzzle.fullDatabase
        var pool = db.filter { p in
            priorityThemes.contains(p.theme) && (difficulty == nil || p.difficulty == difficulty)
        }
        if pool.isEmpty {
            pool = db.filter { priorityThemes.contains($0.theme) }
        }
        if pool.isEmpty {
            pool = db.filter { baseThemes.contains($0.theme) }
        }

        // Bias: if weak themes exist, guarantee one weak-theme puzzle a slot
        var result: [ChessPuzzle] = []
        if !relevantWeakThemes.isEmpty,
           let weakPuzzle = pool.filter({ relevantWeakThemes.contains($0.theme) }).randomElement() {
            result.append(weakPuzzle)
        }
        let remaining = pool.filter { p in !result.contains(where: { $0.id == p.id }) }.shuffled()
        result += Array(remaining.prefix(count - result.count))
        // Shuffle the final order too -- otherwise the guaranteed weak-theme
        // puzzle always leads and every session opens the same way.
        return result.shuffled()
    }

    // MARK: - Blunder Reduction Protocol Questions
    func blunderCheckQuestions(for board: ChessBoard) -> [String] {
        var questions: [String] = []
        let engine = ChessEngineService.shared
        let color = board.activeColor

        questions.append("What changed in the position after my opponent's last move?")
        questions.append("What is my opponent threatening right now?")

        if engine.isInCheck(board: board, color: color) {
            questions.append("I am in check! How do I get out?")
        }

        questions.append("Are there any immediate checks I need to be aware of?")
        questions.append("Are there any captures available to my opponent?")
        questions.append("What are the candidate moves and which is best?")

        return questions
    }

    // MARK: - Coach Insight Generator
    func generateCoachInsight(for move: ChessMove, board: ChessBoard, profile: PlayerProfile) -> CoachInsight {
        let engine = ChessEngineService.shared
        let newBoard = engine.applyMove(move, to: board)
        let isInCheck = engine.isInCheck(board: newBoard, color: newBoard.activeColor)

        var insight = CoachInsight()
        insight.moveQuality = assessMoveQuality(move: move, board: board, profile: profile)
        insight.strategicIdea = strategicExplanation(move: move, board: board)
        insight.tacticalReason = tacticalExplanation(move: move, board: board, isCheck: isInCheck)
        insight.tournamentAdvice = tournamentAdvice(move: move, profile: profile)
        return insight
    }

    private func assessMoveQuality(move: ChessMove, board: ChessBoard, profile: PlayerProfile) -> MoveQuality {
        let engine = ChessEngineService.shared
        let bestMove = engine.bestMove(for: board.activeColor, on: board, depth: 2)

        if let best = bestMove, best.from == move.from && best.to == move.to {
            return .best
        }

        let boardAfter = engine.applyMove(move, to: board)
        let eval = engine.evaluate(board: boardAfter)
        let sign = board.activeColor == .white ? 1 : -1

        if eval * sign >= 200 { return .good }
        if eval * sign >= 0 { return .acceptable }
        if eval * sign >= -100 { return .inaccuracy }
        if eval * sign >= -300 { return .mistake }
        return .blunder
    }

    private func strategicExplanation(move: ChessMove, board: ChessBoard) -> String {
        switch move.piece.type {
        case .pawn:
            if abs(move.to.rank - move.from.rank) == 2 { return "Center pawn advance gains space." }
            return "Pawn move improves pawn structure."
        case .knight:
            return "Knight development to an active square."
        case .bishop:
            return "Bishop development controls a long diagonal."
        case .rook:
            return "Rook activates on an open or semi-open file."
        case .queen:
            return "Queen enters the game with tempo."
        case .king:
            if move.isCastling { return "Castling ensures king safety and connects the rooks." }
            return "King moves toward an active position in the endgame."
        }
    }

    private func tacticalExplanation(move: ChessMove, board: ChessBoard, isCheck: Bool) -> String? {
        if isCheck { return "This move delivers check, forcing the opponent to respond." }
        if move.isCapture { return "Captures material, improving your position." }
        return nil
    }

    private func tournamentAdvice(move: ChessMove, profile: PlayerProfile) -> String {
        switch profile.band {
        case .bandA: return "Remember to check if your opponent can capture anything after this move."
        case .bandB: return "Consider the resulting pawn structure after this move."
        case .bandC: return "Calculate 3-4 moves ahead before committing to this plan."
        case .bandD: return "Think about the resulting pawn structure and long-term plans."
        case .bandE: return "Consider prophylaxis — what is your opponent trying to do?"
        }
    }
}

// MARK: - Coach Insight
struct CoachInsight {
    var moveQuality: MoveQuality = .acceptable
    var strategicIdea: String = ""
    var tacticalReason: String? = nil
    var tournamentAdvice: String = ""
    var nextChallenge: String = ""

    var qualityIcon: String { moveQuality.icon }
    var qualityColor: String { moveQuality.color }
}

enum MoveQuality: String {
    case best = "Best Move"
    case good = "Good"
    case acceptable = "Acceptable"
    case inaccuracy = "Inaccuracy"
    case mistake = "Mistake"
    case blunder = "Blunder"

    var icon: String {
        switch self {
        case .best:       return "!!"
        case .good:       return "!"
        case .acceptable: return "✓"
        case .inaccuracy: return "⁉️"
        case .mistake:    return "?"
        case .blunder:    return "??"
        }
    }

    var color: String {
        switch self {
        case .best, .good: return "green"
        case .acceptable:  return "blue"
        case .inaccuracy:  return "yellow"
        case .mistake:     return "orange"
        case .blunder:     return "red"
        }
    }
}
