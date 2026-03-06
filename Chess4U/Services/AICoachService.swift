import Foundation
import Combine

// MARK: - AI Coach Service
final class AICoachService: ObservableObject, @unchecked Sendable {
    static let shared = AICoachService()
    private init() {}

    @Published var currentAdvice: String = ""
    @Published var isThinking: Bool = false

    // MARK: - Generate Position Commentary (Silman's Imbalances Methodology)
    func generateCommentary(for board: ChessBoard, profile: PlayerProfile) -> String {
        let engine = ChessEngineService.shared
        let eval = engine.evaluate(board: board)
        let isWhiteTurn = board.activeColor == .white
        let isCheck = engine.isInCheck(board: board, color: board.activeColor)
        let legalMoves = engine.legalMoves(for: board.activeColor, on: board)

        if legalMoves.isEmpty {
            if isCheck {
                return "\(board.activeColor.opposite.rawValue.capitalized) wins by checkmate! Well played."
            }
            return "Stalemate! The game is drawn."
        }

        if isCheck {
            return "⚠️ You are in check! You must move out of check. Look for: block, capture the checking piece, or move the king."
        }

        let imbalances = analyzeImbalances(board: board, isWhiteTurn: isWhiteTurn, eval: eval)
        let plan = generatePlan(imbalances: imbalances, board: board, profile: profile, legalMoves: legalMoves)

        if let topImbalance = imbalances.first {
            return "\(topImbalance)\n\n\(plan)"
        }
        return plan
    }

    // MARK: - Silman's Seven Imbalances Analysis
    private func analyzeImbalances(board: ChessBoard, isWhiteTurn: Bool, eval: Int) -> [String] {
        var imbalances: [String] = []
        let advantage = isWhiteTurn ? eval : -eval

        // 1. Material Imbalance
        if abs(advantage) >= 50 {
            if advantage > 0 {
                let pawns = String(format: "%.1f", Double(advantage) / 100.0)
                imbalances.append("⚖️ Material: You are up \(pawns) pawns. Convert this advantage with accurate play.")
            } else {
                let pawns = String(format: "%.1f", Double(-advantage) / 100.0)
                imbalances.append("⚖️ Material: You are down \(pawns) pawns. Seek counterplay and complications.")
            }
        }

        // 2. Pawn Structure
        let myPawns = board.squares.compactMap { $0 }.filter { $0.type == .pawn && $0.color == (isWhiteTurn ? .white : .black) }
        let myPawnFiles = myPawns.map { $0.square.file }
        let doubledFiles = Dictionary(grouping: myPawnFiles, by: { $0 }).filter { $0.value.count > 1 }
        if !doubledFiles.isEmpty {
            imbalances.append("♟️ Pawn Structure: You have doubled pawns — a long-term weakness. Try to eliminate or trade them.")
        }

        // 3. Space
        let myPieceSquares = board.squares.compactMap { $0 }.filter { $0.color == (isWhiteTurn ? .white : .black) && $0.type != .king }
        let centerControl = myPieceSquares.filter { (3...4).contains($0.square.file) && (3...4).contains($0.square.rank) }.count
        if centerControl >= 2 {
            imbalances.append("🏰 Space: You control the center. Use this space advantage to launch an attack.")
        } else if centerControl == 0 {
            imbalances.append("🏰 Space: Your opponent controls more center space. Fight back with pawn breaks.")
        }

        // 4. Minor Piece Quality (Bishop vs Knight)
        let myBishops = myPieceSquares.filter { $0.type == .bishop }.count
        let myKnights = myPieceSquares.filter { $0.type == .knight }.count
        let oppPieces = board.squares.compactMap { $0 }.filter { $0.color == (isWhiteTurn ? .black : .white) && $0.type != .king }
        let oppBishops = oppPieces.filter { $0.type == .bishop }.count
        if myBishops == 2 && oppBishops < 2 {
            imbalances.append("🔷 Minor Pieces: You have the bishop pair — powerful in open positions. Open the position!")
        } else if myKnights >= 2 && myBishops == 0 {
            imbalances.append("🐴 Minor Pieces: Knights excel in closed positions. Keep the pawn structure blocked.")
        }

        // 5. Open Files & Key Squares
        let myRooks = myPieceSquares.filter { $0.type == .rook }
        for rook in myRooks {
            let file = rook.square.file
            let pawnsOnFile = board.squares.compactMap { $0 }.filter { $0.type == .pawn && $0.square.file == file }
            if pawnsOnFile.isEmpty {
                imbalances.append("🏹 Open Files: Your rook is on an open file. Double rooks or invade the 7th rank!")
                break
            }
        }

        return imbalances
    }

    private func generatePlan(imbalances: [String], board: ChessBoard, profile: PlayerProfile, legalMoves: [ChessMove]) -> String {
        let blunderCheck = TreeOfThoughtEngine.shared.blunderCheckQuestions(for: board)
        let questions = blunderCheck.prefix(2).joined(separator: " ")

        switch profile.band {
        case .bandA:
            return "💡 Ask yourself: \(questions)\nFocus on: develop all pieces, castle for king safety, control the center."
        case .bandB:
            return "💡 Think: \(questions)\nIdentify your worst-placed piece and improve it. Look for forks and pins."
        case .bandC:
            let imbalanceHint = imbalances.isEmpty ? "Find a pawn break or tactical opportunity." : "Act on your key imbalance."
            return "💡 Calculate: \(questions)\n\(imbalanceHint) Calculate at least 3 moves deep."
        case .bandD:
            return "💡 Prophylaxis first: \(questions)\nWhat is your opponent threatening? Stop their plan, then execute yours."
        case .bandE:
            return "💡 Silman's method: identify ALL imbalances, then make a plan that exploits the most important one.\n\(questions)"
        }
    }

    // MARK: - Generate Hint
    func generateHint(for puzzle: ChessPuzzle, level: HintLevel, board: ChessBoard) -> String {
        switch level {
        case .none:
            return "No hints available. Try to solve it yourself!"
        case .minimal:
            return "💡 Look for a \(puzzle.theme.rawValue) pattern."
        case .medium:
            return "💡 \(puzzle.hint ?? "Look carefully at all forcing moves: checks, captures, and threats.")"
        case .full:
            let firstMove = puzzle.solution.first ?? ""
            if let sq = Square(algebraic: String(firstMove.prefix(2))) {
                let fileChar = "abcdefgh"[String.Index(utf16Offset: sq.file, in: "abcdefgh")]
                return "💡 Start with a move from the \(fileChar) file. \(puzzle.hint ?? "")"
            }
            return "💡 \(puzzle.hint ?? puzzle.explanation)"
        }
    }

    // MARK: - Variation Practice Commentary
    func variationComment(move: ChessMove, expectedMove: String, isCorrect: Bool) -> String {
        if isCorrect {
            let comments = [
                "Excellent! That's the right move.",
                "Well calculated! You found the key move.",
                "Perfect! Your calculation is improving.",
                "Great move! You're thinking like a strong player.",
                "Exactly right! This is the critical move in this variation."
            ]
            return comments.randomElement()!
        } else {
            return """
            Not quite right. You played \(move.notation).
            Consider: What was your opponent's last threat?
            In this position, the main idea is to \(variationHint(theme: .middlegameTactics)).
            Try again, thinking about forcing moves first.
            """
        }
    }

    private func variationHint(theme: PuzzleTheme) -> String {
        switch theme {
        case .fork: return "attack two pieces simultaneously"
        case .pin: return "pin a piece to a more valuable target"
        case .skewer: return "attack through a valuable piece to another behind it"
        case .discoveredAttack: return "move one piece to unleash an attack from another"
        case .deflection: return "force a key defender away from its duty"
        case .mateInOne, .mateInTwo, .mateInThree: return "deliver checkmate"
        default: return "find the most forcing move"
        }
    }

    // MARK: - Generate Lesson Audio Script
    func generateAudioScript(for lesson: ConceptLesson) -> String {
        return """
        Welcome to today's chess lesson: \(lesson.title).

        Today we're going to study \(lesson.concept).

        \(lesson.explanation)

        Here's an example to illustrate this:
        \(lesson.example)

        The key idea to remember is:
        \(lesson.keyIdea)

        A common mistake players make is:
        \(lesson.commonMistake)

        Strong players use this concept by:
        \(lesson.howStrongPlayersUseIt)

        Now it's your turn to practice. Let's work through some positions together.
        Remember: chess improvement comes from consistent practice and deep understanding.
        Keep studying, and your game will improve!
        """
    }

    // MARK: - Game Analysis
    func analyzeGame(_ game: ChessGame, profile: PlayerProfile) -> GameAnalysis {
        let engine = ChessEngineService.shared
        var criticalMistakes: [MoveAnalysis] = []
        let missedTactics: [MoveAnalysis] = []
        var goodMoves: [MoveAnalysis] = []
        var evaluations: [Double] = [0.0]

        var currentBoard = ChessBoard()

        for (idx, move) in game.moves.enumerated() {
            let evaluation = Double(engine.evaluate(board: currentBoard)) / 100.0
            evaluations.append(evaluation)

            let bestMove = engine.bestMove(for: currentBoard.activeColor, on: currentBoard, depth: 2)
            let quality = assessQuality(move: move, bestMove: bestMove, board: currentBoard)

            let analysis = MoveAnalysis(
                moveNumber: idx + 1,
                move: move,
                quality: quality,
                explanation: explanationFor(quality: quality, move: move),
                evaluation: evaluation
            )

            switch quality {
            case .blunder, .mistake:
                criticalMistakes.append(analysis)
            case .best, .good:
                goodMoves.append(analysis)
            default:
                break
            }

            currentBoard = engine.applyMove(move, to: currentBoard)
        }

        let accuracy = calculateAccuracy(moves: game.moves.count, mistakes: criticalMistakes.count)
        let summary = generateSummary(accuracy: accuracy, mistakes: criticalMistakes, profile: profile)

        return GameAnalysis(
            game: game,
            summary: summary,
            criticalMistakes: criticalMistakes,
            missedTactics: missedTactics,
            goodMoves: goodMoves,
            accuracy: accuracy,
            evaluationHistory: evaluations,
            improvementAdvice: generateImprovementAdvice(criticalMistakes: criticalMistakes, profile: profile)
        )
    }

    private func assessQuality(move: ChessMove, bestMove: ChessMove?, board: ChessBoard) -> MoveQuality {
        let engine = ChessEngineService.shared
        guard let best = bestMove else { return .acceptable }

        if best.from == move.from && best.to == move.to { return .best }

        let boardAfterBest = engine.applyMove(best, to: board)
        let boardAfterMove = engine.applyMove(move, to: board)

        let sign = board.activeColor == .white ? 1 : -1
        let evalBest = engine.evaluate(board: boardAfterBest) * sign
        let evalMove = engine.evaluate(board: boardAfterMove) * sign
        let diff = evalBest - evalMove

        if diff <= 30 { return .good }
        if diff <= 100 { return .acceptable }
        if diff <= 200 { return .inaccuracy }
        if diff <= 400 { return .mistake }
        return .blunder
    }

    private func explanationFor(quality: MoveQuality, move: ChessMove) -> String {
        switch quality {
        case .best: return "This was the best move in the position."
        case .good: return "Good move, close to the best continuation."
        case .acceptable: return "An acceptable move, though better options existed."
        case .inaccuracy: return "A slight inaccuracy. Consider more careful calculation."
        case .mistake: return "This move gives away some advantage. Your opponent could have punished it."
        case .blunder: return "⚠️ This was a blunder! Always check for opponent's threats before moving."
        }
    }

    private func calculateAccuracy(moves: Int, mistakes: Int) -> Double {
        guard moves > 0 else { return 100 }
        let goodMoves = max(0, moves - mistakes)
        return Double(goodMoves) / Double(moves) * 100
    }

    private func generateSummary(accuracy: Double, mistakes: [MoveAnalysis], profile: PlayerProfile) -> String {
        let accuracyStr = String(format: "%.1f", accuracy)
        let mistakeCount = mistakes.count
        let blunders = mistakes.filter { $0.quality == .blunder }.count

        var summary = "Game Accuracy: \(accuracyStr)%\n"
        summary += "Critical mistakes: \(mistakeCount) (\(blunders) blunders)\n\n"

        if accuracy >= 90 {
            summary += "Excellent game! You played very accurately."
        } else if accuracy >= 75 {
            summary += "Good game with some imprecisions. Focus on the highlighted mistakes."
        } else if accuracy >= 60 {
            summary += "Room for improvement. Work on calculation and blunder prevention."
        } else {
            summary += "This was a tough game. Focus on blunder prevention and basic tactics."
        }

        return summary
    }

    private func generateImprovementAdvice(criticalMistakes: [MoveAnalysis], profile: PlayerProfile) -> [String] {
        var advice: [String] = []

        let blunders = criticalMistakes.filter { $0.quality == .blunder }
        if !blunders.isEmpty {
            advice.append("Work on blunder prevention: always ask 'What can my opponent do?' before moving.")
        }

        switch profile.band {
        case .bandA:
            advice.append("Practice basic tactics daily — forks, pins, and back rank mates.")
            advice.append("Review the three opening principles: center control, development, king safety.")
        case .bandB:
            advice.append("Study tactical patterns systematically to improve pattern recognition.")
            advice.append("Learn common pawn structures and their associated plans.")
        case .bandC:
            advice.append("Work on calculation discipline — always calculate to a quiet position.")
            advice.append("Study the games of masters to improve strategic understanding.")
        case .bandD:
            advice.append("Focus on prophylaxis — prevent your opponent's plans before executing yours.")
            advice.append("Study endgame technique to convert winning positions more reliably.")
        case .bandE:
            advice.append("Deep opening preparation will help you get better positions from the start.")
            advice.append("Work on precise calculation in complex positions.")
        }

        return advice
    }
}

// MARK: - Game Analysis
struct GameAnalysis {
    var game: ChessGame
    var summary: String
    var criticalMistakes: [MoveAnalysis]
    var missedTactics: [MoveAnalysis]
    var goodMoves: [MoveAnalysis]
    var accuracy: Double
    var evaluationHistory: [Double]
    var improvementAdvice: [String]
}

struct MoveAnalysis: Identifiable {
    var id = UUID()
    var moveNumber: Int
    var move: ChessMove
    var quality: MoveQuality
    var explanation: String
    var evaluation: Double
    var bestAlternative: ChessMove? = nil
}
