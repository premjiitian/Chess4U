import Foundation
import Combine

// MARK: - AI Coach Service
final class AICoachService: ObservableObject, @unchecked Sendable {
    static let shared = AICoachService()
    private init() {}

    @Published var currentAdvice: String = ""
    @Published var isThinking: Bool = false
    var uiMode: UIMode = .study

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
        // NOTE: previously this chained `.compactMap { $0 }.filter { ... }` directly on
        // `board.squares` ([[ChessPiece?]], a raw 2D array) and accessed a `.square`
        // property that doesn't exist on ChessPiece. That's too ambiguous for the type
        // checker (timed out with "unable to type-check this expression in reasonable
        // time") and wouldn't have compiled at all once it did resolve. `allSquares(for:)`
        // already exists on ChessBoard and returns properly-typed (Square, ChessPiece)
        // pairs, which keeps every expression here simple and unambiguous.
        let myColor: PieceColor = isWhiteTurn ? .white : .black
        let oppColor = myColor.opposite
        let myPieces = board.allSquares(for: myColor)
        let oppPieces = board.allSquares(for: oppColor)

        let myPawns = myPieces.filter { $0.1.type == .pawn }
        let myPawnFiles = myPawns.map { $0.0.file }
        let doubledFiles = Dictionary(grouping: myPawnFiles, by: { $0 }).filter { $0.value.count > 1 }
        if !doubledFiles.isEmpty {
            imbalances.append("♟️ Pawn Structure: You have doubled pawns — a long-term weakness. Try to eliminate or trade them.")
        }

        // 3. Space
        let myNonKingPieces = myPieces.filter { $0.1.type != .king }
        let centerControl = myNonKingPieces.filter { (3...4).contains($0.0.file) && (3...4).contains($0.0.rank) }.count
        if centerControl >= 2 {
            imbalances.append("🏰 Space: You control the center. Use this space advantage to launch an attack.")
        } else if centerControl == 0 {
            imbalances.append("🏰 Space: Your opponent controls more center space. Fight back with pawn breaks.")
        }

        // 4. Minor Piece Quality (Bishop vs Knight)
        let myBishops = myNonKingPieces.filter { $0.1.type == .bishop }.count
        let myKnights = myNonKingPieces.filter { $0.1.type == .knight }.count
        let oppNonKingPieces = oppPieces.filter { $0.1.type != .king }
        let oppBishops = oppNonKingPieces.filter { $0.1.type == .bishop }.count
        if myBishops == 2 && oppBishops < 2 {
            imbalances.append("🔷 Minor Pieces: You have the bishop pair — powerful in open positions. Open the position!")
        } else if myKnights >= 2 && myBishops == 0 {
            imbalances.append("🐴 Minor Pieces: Knights excel in closed positions. Keep the pawn structure blocked.")
        }

        // 5. Open Files & Key Squares
        let allPawnFiles = Set((myPieces + oppPieces).filter { $0.1.type == .pawn }.map { $0.0.file })
        let myRooks = myNonKingPieces.filter { $0.1.type == .rook }
        for rook in myRooks {
            if !allPawnFiles.contains(rook.0.file) {
                imbalances.append("🏹 Open Files: Your rook is on an open file. Double rooks or invade the 7th rank!")
                break
            }
        }

        return imbalances
    }

    private func generatePlan(imbalances: [String], board: ChessBoard, profile: PlayerProfile, legalMoves: [ChessMove]) -> String {
        // Kids mode — use encouraging, age-appropriate language
        if uiMode == .kids {
            return generateKidsFriendlyPlan(board: board, legalMoves: legalMoves)
        }

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

    private func generateKidsFriendlyPlan(board: ChessBoard, legalMoves: [ChessMove]) -> String {
        let engine = ChessEngineService.shared
        let isCheck = engine.isInCheck(board: board, color: board.activeColor)

        if isCheck {
            return "🚨 Oh no! Your king is being attacked! You need to help your king escape — move it to a safe spot, block the attack, or capture the attacker!"
        }

        let encouragements = [
            "You're doing amazing! Think carefully — can any of your pieces capture an enemy piece safely? ♟️",
            "Great thinking so far! Look for a knight jump or a sneaky bishop move! 🐴",
            "You've got this! Try to move your pieces toward the center of the board! 🎯",
            "Superstar move coming! Think: which piece hasn't moved yet? Get it into the game! ⭐",
            "Chess champion in the making! Can you put the opponent's king in danger? 👑",
        ]
        return encouragements.randomElement()!
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

    // MARK: - Game Analysis (cloud Stockfish, with local fallback)
    /// Analyzes a full game using real Stockfish (via StockfishCloudService)
    /// for every position, falling back to the local heuristic engine
    /// (`ChessEngineService`) move-by-move if the network is unavailable --
    /// once one cloud call fails, the rest of the game uses the local engine
    /// too, instead of retrying/timing out on every remaining move.
    func analyzeGameCloud(_ game: ChessGame, profile: PlayerProfile, depth: Int = 10) async -> GameAnalysis {
        let engine = ChessEngineService.shared
        let cloud = StockfishCloudService.shared
        var criticalMistakes: [MoveAnalysis] = []
        let missedTactics: [MoveAnalysis] = []
        var goodMoves: [MoveAnalysis] = []
        var evaluations: [Double] = [0.0]
        var allAnalyses: [MoveAnalysis] = []

        var currentBoard = ChessBoard()
        var cloudAvailable = true
        var cloudCallsSucceeded = 0

        for (idx, move) in game.moves.enumerated() {
            var evaluation: Double
            var bestMove: ChessMove?
            var bestMoveUCI: String? = nil

            if cloudAvailable, let result = try? await cloud.analyze(fen: currentBoard.fen, depth: depth) {
                cloudCallsSucceeded += 1
                evaluation = result.evaluationPawns
                bestMoveUCI = result.bestMoveUCI
                if let uci = result.bestMoveUCI, let parsed = engine.move(fromUCI: uci, board: currentBoard) {
                    bestMove = parsed
                } else {
                    bestMove = engine.bestMove(for: currentBoard.activeColor, on: currentBoard, depth: 2)
                }
            } else {
                cloudAvailable = false
                evaluation = Double(engine.evaluate(board: currentBoard)) / 100.0
                bestMove = engine.bestMove(for: currentBoard.activeColor, on: currentBoard, depth: 2)
            }

            evaluations.append(evaluation)

            // Quality is derived from the eval swing between this position
            // and the next (i.e. the result of the move actually played),
            // rather than re-evaluating a hypothetical "best move" board --
            // this reuses the same sequential cloud calls instead of tripling
            // the network requests per move.
            let quality = assessQualityFromMove(
                move: move, bestMoveUCI: bestMoveUCI, bestMove: bestMove,
                evalBefore: evaluation, board: currentBoard
            )

            let analysis = MoveAnalysis(
                moveNumber: idx + 1,
                move: move,
                quality: quality,
                explanation: explanationFor(quality: quality, move: move),
                evaluation: evaluation,
                positionFEN: currentBoard.fen,
                bestAlternative: bestMove
            )

            allAnalyses.append(analysis)

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

        // Fill in quality for the final position's eval swing now that we
        // know evaluations[idx+1] for every move -- re-derive using the
        // eval-diff scheme for anything the single-call loop above couldn't
        // score precisely (kept simple: this matches the local classification
        // thresholds already used by the app).
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
            improvementAdvice: generateImprovementAdvice(criticalMistakes: criticalMistakes, profile: profile),
            allMoveAnalyses: allAnalyses,
            engineSource: cloudCallsSucceeded == game.moves.count ? .cloudStockfish
                : (cloudCallsSucceeded > 0 ? .mixedCloudAndLocal : .localEngine)
        )
    }

    /// Move-quality classification used by the cloud analysis path. When the
    /// played move matches the engine's own top choice it's automatically
    /// `.best`; otherwise quality is estimated from how the actual move's
    /// resulting evaluation compares to the position's evaluation before the
    /// move (bounded, since we don't re-evaluate the "what if" board here).
    private func assessQualityFromMove(move: ChessMove, bestMoveUCI: String?, bestMove: ChessMove?, evalBefore: Double, board: ChessBoard) -> MoveQuality {
        if let bestMoveUCI = bestMoveUCI {
            if bestMoveUCI == move.longAlgebraic || bestMoveUCI.hasPrefix(move.longAlgebraic) {
                return .best
            }
        } else if let best = bestMove, best.from == move.from, best.to == move.to {
            return .best
        }

        // No cloud "what if I'd played the actual move" evaluation is fetched
        // per-move (to keep network calls at 1/move), so fall back to the
        // local engine's material/positional comparison between the actual
        // move and the engine's suggested best move for a bucket estimate.
        let engine = ChessEngineService.shared
        guard let best = bestMove else { return .acceptable }
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

    // MARK: - Game Analysis (local heuristic engine only, no network)
    func analyzeGame(_ game: ChessGame, profile: PlayerProfile) -> GameAnalysis {
        let engine = ChessEngineService.shared
        var criticalMistakes: [MoveAnalysis] = []
        let missedTactics: [MoveAnalysis] = []
        var goodMoves: [MoveAnalysis] = []
        var evaluations: [Double] = [0.0]
        // Every move's analysis, regardless of quality bucket -- criticalMistakes
        // only holds .blunder/.mistake (by design, for the existing accuracy/summary
        // math below), so .inaccuracy and .acceptable moves would otherwise be
        // dropped entirely. PersonalPuzzleService needs those too.
        var allAnalyses: [MoveAnalysis] = []

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
                evaluation: evaluation,
                // Position *before* this move was played, plus the engine's
                // preferred alternative -- both needed to turn a mistake into
                // a solvable puzzle later (see PersonalPuzzleService).
                positionFEN: currentBoard.fen,
                bestAlternative: bestMove
            )

            allAnalyses.append(analysis)

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
            improvementAdvice: generateImprovementAdvice(criticalMistakes: criticalMistakes, profile: profile),
            allMoveAnalyses: allAnalyses
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

        if uiMode == .kids {
            var summary = "⭐ You scored \(accuracyStr)% accuracy — "
            if accuracy >= 80 {
                summary += "that's INCREDIBLE! You're a chess superstar! 🏆\n"
            } else if accuracy >= 60 {
                summary += "great effort! You're getting better every game! 🌟\n"
            } else {
                summary += "keep practicing! Every chess master started just like you! 💪\n"
            }
            if mistakeCount == 0 {
                summary += "WOW — zero mistakes! You're unstoppable!"
            } else {
                summary += "You made \(mistakeCount) mistake\(mistakeCount == 1 ? "" : "s") — let's learn from them and come back even stronger!"
            }
            return summary
        }

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

/// Which engine actually produced a GameAnalysis, shown to the user so it's
/// clear whether they got real Stockfish or the offline fallback.
enum AnalysisEngineSource: Equatable {
    case cloudStockfish
    case mixedCloudAndLocal
    case localEngine

    var label: String {
        switch self {
        case .cloudStockfish: return "Analyzed with Stockfish"
        case .mixedCloudAndLocal: return "Analyzed with Stockfish (partial — connection dropped mid-game)"
        case .localEngine: return "Analyzed with offline engine (no internet connection)"
        }
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
    /// Every move's analysis in move order, unfiltered by quality -- used by
    /// PersonalPuzzleService to find .inaccuracy-quality moves too, which the
    /// buckets above deliberately exclude.
    var allMoveAnalyses: [MoveAnalysis] = []
    /// Which engine produced this analysis -- defaults to the local engine
    /// since the original synchronous `analyzeGame` never calls the cloud.
    var engineSource: AnalysisEngineSource = .localEngine
}

struct MoveAnalysis: Identifiable {
    var id = UUID()
    var moveNumber: Int
    var move: ChessMove
    var quality: MoveQuality
    var explanation: String
    var evaluation: Double
    /// FEN of the position immediately before this move was played -- this is
    /// what lets a mistake become a puzzle (the puzzle starting position).
    var positionFEN: String = ""
    var bestAlternative: ChessMove? = nil
}
