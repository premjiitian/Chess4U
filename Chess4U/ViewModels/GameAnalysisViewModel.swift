import SwiftUI
import Combine

@MainActor
class GameAnalysisViewModel: ObservableObject {
    @Published var game: ChessGame?
    @Published var analysis: GameAnalysis?
    @Published var boardVM: ChessBoardViewModel = ChessBoardViewModel()
    @Published var currentMoveIndex: Int = 0
    @Published var isAnalyzing: Bool = false
    @Published var selectedMistake: MoveAnalysis? = nil
    @Published var showAudioExplanation: Bool = false
    /// Brief confirmation text shown after "Save Position" is tapped, e.g.
    /// "Saved to My Puzzles" -- nil the rest of the time.
    @Published var saveConfirmation: String? = nil

    private let aiCoach = AICoachService.shared
    private let audioCoach = AudioCoachService.shared
    private let engine = ChessEngineService.shared
    private let persistence = PersistenceService.shared
    var profile: PlayerProfile?
    var uiMode: UIMode = .study
    /// Set by ImportGamesView so a saved position can be tagged with the
    /// platform/date it came from; nil when the game wasn't from an import.
    var sourceGame: ExternalGame?

    func analyzeGame(_ game: ChessGame) {
        self.game = game
        boardVM = ChessBoardViewModel(profile: profile)

        // Build a default profile so analysis always runs even when the user
        // hasn't completed onboarding yet — avoids the UI hanging on "Analyzing…".
        let effectiveProfile = profile ?? PlayerProfile(
            name: "Player", elo: 1000,
            preferredTimeControl: .rapid, playerType: .casual,
            mainOpeningsWhite: [], mainDefensesBlack: [],
            ratingTrend: .stable, weaknesses: [.tactics]
        )

        isAnalyzing = true
        let aiCoach = self.aiCoach  // capture before leaving MainActor context
        aiCoach.uiMode = self.uiMode

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = aiCoach.analyzeGame(game, profile: effectiveProfile)
            DispatchQueue.main.async {
                self?.analysis = result
                self?.isAnalyzing = false
            }
        }
    }

    func goToMove(_ index: Int) {
        guard let game = game else { return }
        currentMoveIndex = min(max(0, index), game.moves.count)
        reconstructBoard(upToMove: currentMoveIndex)
    }

    func nextMove() { goToMove(currentMoveIndex + 1) }
    func previousMove() { goToMove(currentMoveIndex - 1) }
    func firstMove() { goToMove(0) }
    func lastMove() { goToMove(game?.moves.count ?? 0) }

    private func reconstructBoard(upToMove index: Int) {
        boardVM = ChessBoardViewModel(profile: profile)
        guard let game = game else { return }
        for i in 0..<min(index, game.moves.count) {
            boardVM.game.makeMove(game.moves[i])
        }
        if index > 0 && index <= game.moves.count {
            boardVM.lastMove = game.moves[index - 1]
        }
    }

    /// Saves the position currently on the board (at `currentMoveIndex`) as a
    /// puzzle in "My Puzzles", with the engine's best move as the solution.
    /// Lets the player bookmark any moment in the game, not just the ones
    /// auto-flagged as mistakes.
    @discardableResult
    func saveCurrentPositionAsPuzzle() -> Bool {
        let board = boardVM.game.board
        guard let best = engine.bestMove(for: board.activeColor, on: board, depth: 2) else {
            saveConfirmation = "No legal moves in this position to save."
            return false
        }

        let mover = board.activeColor
        let opponentName: String = {
            guard let game = game else { return "" }
            return mover == .white ? game.blackPlayer : game.whitePlayer
        }()
        let titleSuffix = opponentName.isEmpty ? "" : " vs \(opponentName)"

        let puzzle = ChessPuzzle(
            fen: board.fen,
            solution: [best.longAlgebraic],
            theme: .personalBookmark,
            difficulty: .medium,
            playerToMove: mover,
            rating: profile?.elo ?? 1200,
            title: "Saved position — Move \(currentMoveIndex)\(titleSuffix)",
            explanation: "You bookmarked this position while reviewing your game. Find the strongest continuation.",
            hint: "Look carefully at all your candidate moves before deciding.",
            sourcePlatform: sourceGame?.platform.rawValue,
            sourceGameID: sourceGame?.id,
            sourceDate: sourceGame?.endTime ?? Date(),
            sourceWhiteRating: sourceGame?.whiteRating,
            sourceBlackRating: sourceGame?.blackRating,
            sourceWhitePlayer: game?.whitePlayer,
            sourceBlackPlayer: game?.blackPlayer
        )

        let added = persistence.addPersonalPuzzles([puzzle])
        saveConfirmation = added > 0 ? "Saved to My Puzzles" : "You already saved this exact position."
        return added > 0
    }

    func speakAnalysis() {
        guard let analysis = analysis else { return }
        audioCoach.speak(analysis.summary)
        if let firstMistake = analysis.criticalMistakes.first {
            audioCoach.speakMoveAnalysis(quality: firstMistake.quality, explanation: firstMistake.explanation)
        }
    }

    var evaluationGraphData: [Double] {
        analysis?.evaluationHistory ?? []
    }

    var moveQualityColor: Color {
        guard let move = selectedMistake else { return .gray }
        switch move.quality {
        case .best, .good: return .green
        case .acceptable:  return .blue
        case .inaccuracy:  return .yellow
        case .mistake:     return .orange
        case .blunder:     return .red
        }
    }
}
