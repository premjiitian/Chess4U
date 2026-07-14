import Foundation

// MARK: - Personal Puzzle Service
/// Turns the mistakes, inaccuracies, and blunders found by `AICoachService.analyzeGame`
/// into solvable `ChessPuzzle`s sourced from the player's own imported chess.com/Lichess
/// games -- the "puzzle book from your own games" feature.
final class PersonalPuzzleService: @unchecked Sendable {
    static let shared = PersonalPuzzleService()
    private init() {}

    /// Which move qualities are worth turning into a puzzle. Matches the
    /// player's own framing: "mistakes, inaccuracies, blunders."
    private let puzzleWorthyQualities: Set<MoveQuality> = [.inaccuracy, .mistake, .blunder]

    /// Builds one puzzle per qualifying mistake in a single analyzed game.
    /// - Parameters:
    ///   - analysis: Result of `AICoachService.shared.analyzeGame(_:profile:)`.
    ///   - game: The source `ExternalGame` metadata (platform, opponent names, date).
    func generatePuzzles(from analysis: GameAnalysis, source game: ExternalGame) -> [ChessPuzzle] {
        let qualifying = analysis.allMoveAnalyses.filter { puzzleWorthyQualities.contains($0.quality) }

        return qualifying.compactMap { moveAnalysis -> ChessPuzzle? in
            guard let best = moveAnalysis.bestAlternative,
                  !moveAnalysis.positionFEN.isEmpty else { return nil }

            let mover = moveAnalysis.move.piece.color
            let opponentName = mover == .white ? game.blackPlayer : game.whitePlayer

            return ChessPuzzle(
                fen: moveAnalysis.positionFEN,
                solution: [best.longAlgebraic],
                theme: .personalMistake,
                difficulty: difficulty(for: moveAnalysis.quality),
                playerToMove: mover,
                rating: rating(for: moveAnalysis.quality),
                title: "\(title(for: moveAnalysis.quality)) vs \(opponentName)",
                explanation: explanation(for: moveAnalysis, bestMove: best),
                hint: "Look for a stronger continuation than the move you actually played in this game.",
                sourcePlatform: game.platform.rawValue,
                sourceGameID: game.id,
                sourceDate: game.endTime,
                sourceWhiteRating: game.whiteRating,
                sourceBlackRating: game.blackRating,
                sourceWhitePlayer: game.whitePlayer,
                sourceBlackPlayer: game.blackPlayer
            )
        }
    }

    /// Convenience for a whole batch: imports each game's PGN, analyzes it,
    /// and collects every generated puzzle across the batch.
    func generatePuzzles(from games: [ExternalGame], profile: PlayerProfile) -> [ChessPuzzle] {
        var result: [ChessPuzzle] = []
        for game in games {
            guard let parsed = PGNImporter.importGame(game.pgn) else { continue }
            let analysis = AICoachService.shared.analyzeGame(parsed, profile: profile)
            result.append(contentsOf: generatePuzzles(from: analysis, source: game))
        }
        return result
    }

    // MARK: - Labeling helpers

    private func title(for quality: MoveQuality) -> String {
        switch quality {
        case .blunder:    return "Missed win"
        case .mistake:    return "Costly mistake"
        case .inaccuracy: return "Slight inaccuracy"
        default:          return "Missed best move"
        }
    }

    private func difficulty(for quality: MoveQuality) -> PuzzleDifficulty {
        switch quality {
        case .blunder:    return .hard
        case .mistake:    return .medium
        case .inaccuracy: return .easy
        default:          return .medium
        }
    }

    private func rating(for quality: MoveQuality) -> Int {
        switch quality {
        case .blunder:    return 1650
        case .mistake:    return 1400
        case .inaccuracy: return 1150
        default:          return 1300
        }
    }

    private func explanation(for analysis: MoveAnalysis, bestMove: ChessMove) -> String {
        let played = analysis.move.notation.isEmpty ? analysis.move.longAlgebraic : analysis.move.notation
        let better = bestMove.notation.isEmpty ? bestMove.longAlgebraic : bestMove.notation
        return "In your actual game you played \(played) here. \(better) was significantly stronger. \(analysis.explanation)"
    }
}
