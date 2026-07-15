import SwiftUI
import Combine

@MainActor
class TrainingViewModel: ObservableObject {
    @Published var session: TrainingSession?
    @Published var currentPuzzle: ChessPuzzle?
    @Published var puzzleState: PuzzleState = .idle
    @Published var boardVM: ChessBoardViewModel = ChessBoardViewModel()
    @Published var solutionMoves: [String] = []
    @Published var currentSolutionIndex: Int = 0
    @Published var hintText: String = ""
    @Published var coachComment: String = ""
    @Published var showLesson: Bool = false
    @Published var showBlunderCheck: Bool = false
    @Published var blunderCheckQuestions: [String] = []
    @Published var sessionScore: Int = 0
    @Published var isSessionComplete: Bool = false
    @Published var showCoachInsight: Bool = false

    private let coach = AICoachService.shared
    private let adaptive = AdaptiveDifficultyService.shared
    private let thoughtEngine = TreeOfThoughtEngine.shared
    private var puzzleStartTime: Date = Date()
    private var cancellables = Set<AnyCancellable>()
    private var solvedPuzzleIndices: Set<Int> = []
    /// Guards against double-advancing when the player taps "Next" manually
    /// during the 2s auto-advance window after solving a puzzle.
    private var isAdvancing = false
    var profile: PlayerProfile?

    init(profile: PlayerProfile? = nil) {
        self.profile = profile
    }

    // MARK: - Start Session
    func startSession(type: TrainingType) {
        // Use existing profile or a default so training is accessible immediately.
        let effectiveProfile = profile ?? PlayerProfile(
            name: "Player", elo: 1000,
            preferredTimeControl: .rapid, playerType: .casual,
            mainOpeningsWhite: [], mainDefensesBlack: [],
            ratingTrend: .stable, weaknesses: [.tactics]
        )
        if profile == nil { self.profile = effectiveProfile }
        let profile = effectiveProfile
        // Seed adaptive difficulty from the player's band
        let settings = adaptive.recommendedSettings(for: profile)
        adaptive.currentDifficulty = settings.puzzleDifficulty
        adaptive.shouldShowHints = settings.showHints
        adaptive.shouldShowArrows = settings.showArrows
        solvedPuzzleIndices = []
        session = thoughtEngine.generateSession(type: type, profile: profile,
                                                difficulty: adaptive.currentDifficulty,
                                                weakThemes: profile.weakestThemes)
        showLesson = session?.conceptLesson != nil
        isSessionComplete = false
        sessionScore = 0

        if let firstPuzzle = session?.warmupPuzzles.first {
            loadPuzzle(firstPuzzle)
        }
    }

    // MARK: - Start Custom Session (personal puzzles from imported games)
    /// Builds a session directly from a caller-supplied puzzle list instead
    /// of pulling from the curated database via TreeOfThoughtEngine -- used
    /// by "My Puzzles" to practice mistakes/bookmarks from the player's own
    /// imported games.
    func startCustomSession(type: TrainingType, puzzles: [ChessPuzzle]) {
        let effectiveProfile = profile ?? PlayerProfile(
            name: "Player", elo: 1000,
            preferredTimeControl: .rapid, playerType: .casual,
            mainOpeningsWhite: [], mainDefensesBlack: [],
            ratingTrend: .stable, weaknesses: [.tactics]
        )
        if profile == nil { self.profile = effectiveProfile }
        let profile = effectiveProfile

        let settings = adaptive.recommendedSettings(for: profile)
        adaptive.currentDifficulty = settings.puzzleDifficulty
        adaptive.shouldShowHints = settings.showHints
        adaptive.shouldShowArrows = settings.showArrows
        solvedPuzzleIndices = []

        session = TrainingSession(
            type: type,
            playerBand: profile.band,
            startDate: Date(),
            warmupPuzzles: [],
            mainPuzzles: puzzles
        )
        showLesson = false
        isSessionComplete = false
        sessionScore = 0

        if let firstPuzzle = puzzles.first {
            loadPuzzle(firstPuzzle)
        }
    }

    // MARK: - Load Puzzle
    func loadPuzzle(_ puzzle: ChessPuzzle, index: Int? = nil) {
        isAdvancing = false
        currentPuzzle = puzzle
        solutionMoves = puzzle.solution
        currentSolutionIndex = 0
        puzzleState = .waitingForMove
        puzzleStartTime = Date()
        coachComment = ""
        hintText = ""

        boardVM = ChessBoardViewModel(fen: puzzle.fen, profile: profile)
        boardVM.showHints = adaptive.shouldShowHints

        // Blunder check questions
        blunderCheckQuestions = thoughtEngine.blunderCheckQuestions(for: boardVM.game.board)
    }

    // MARK: - Handle Player Move
    func handlePlayerMove(_ move: ChessMove) {
        guard let puzzle = currentPuzzle, puzzleState == .waitingForMove else { return }
        // The board reports every move made on it -- including the scripted
        // opponent reply this view model plays itself. Grading the opponent's
        // own reply against the player's next expected move flagged every
        // multi-move puzzle "incorrect" right after a correct first move.
        guard move.piece.color == puzzle.playerToMove else { return }

        let expectedMove = solutionMoves[currentSolutionIndex]
        let playerMove = move.longAlgebraic

        if playerMove == expectedMove {
            // Correct move
            currentSolutionIndex += 1
            puzzleState = currentSolutionIndex >= solutionMoves.count ? .solved : .waitingForMove

            if puzzleState == .solved {
                handlePuzzleSolved()
            } else {
                // Make opponent response if it's an odd index
                coachComment = "Correct! Continue..."
                makeOpponentMove()
            }
        } else {
            verifyAlternativeMove(move)
        }
    }

    private func makeOpponentMove() {
        guard currentSolutionIndex < solutionMoves.count else { return }
        let opponentMove = solutionMoves[currentSolutionIndex]
        // Brief pause before the scripted reply so the player actually sees
        // the opponent respond instead of the board mutating instantly.
        puzzleState = .correct
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard self.puzzleState == .correct else { return }
            if let reply = self.parseMove(opponentMove, board: self.boardVM.game.board) {
                self.boardVM.executeMove(reply)
                self.currentSolutionIndex += 1
            }
            self.puzzleState = .waitingForMove
        }
    }

    /// The player's move didn't match the scripted solution. Before calling
    /// it wrong, ask cloud Stockfish whether the played move is actually the
    /// engine-best move in this position -- many puzzles (especially endgames)
    /// have more than one winning continuation. Falls back to the strict
    /// scripted comparison when offline.
    private func verifyAlternativeMove(_ move: ChessMove) {
        puzzleState = .checking
        coachComment = "Checking your move with Stockfish…"

        var playedUCI = move.longAlgebraic
        if let promo = move.promotionPiece { playedUCI += String(promo.fenChar) }

        // Reconstruct the position before the player's move.
        let preGame = ChessGame(fen: currentPuzzle?.fen ?? "")
        for m in boardVM.game.moves.dropLast() { preGame.makeMove(m) }
        let preFEN = preGame.board.fen

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            var matchesEngineBest = false
            if let analysis = try? await StockfishCloudService.shared.analyze(fen: preFEN, depth: 12),
               let best = analysis.bestMoveUCI {
                matchesEngineBest = best == playedUCI
            }
            guard self.puzzleState == .checking else { return }
            if matchesEngineBest {
                self.handlePuzzleSolved()
                self.coachComment = "✅ Not the scripted line, but Stockfish confirms your move is best — well done!"
            } else {
                self.handleIncorrectMove(move)
            }
        }
    }

    private func parseMove(_ algebraic: String, board: ChessBoard) -> ChessMove? {
        // Delegates to the shared UCI parser on ChessEngineService (also used
        // by the cloud Stockfish integration) instead of duplicating the
        // from/to/promotion-matching logic here.
        ChessEngineService.shared.move(fromUCI: algebraic, board: board)
    }

    private func handlePuzzleSolved() {
        puzzleState = .solved
        let timeSpent = Date().timeIntervalSince(puzzleStartTime)
        adaptive.recordResult(correct: true, timeSpent: timeSpent)
        solvedPuzzleIndices.insert(session?.currentPuzzleIndex ?? 0)

        if var puzzle = currentPuzzle {
            puzzle.solvedCorrectly = true
            puzzle.timeSpent = timeSpent
            currentPuzzle = puzzle
        }

        sessionScore += calculateScore()
        coachComment = "Excellent! \(currentPuzzle?.explanation ?? "Well done!")"

        if var session = session {
            session.puzzlesSolved += 1
            session.puzzlesAttempted += 1
            self.session = session
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.advanceToNextPuzzle()
        }
    }

    private func handleIncorrectMove(_ move: ChessMove) {
        puzzleState = .incorrect
        let timeSpent = Date().timeIntervalSince(puzzleStartTime)
        adaptive.recordResult(correct: false, timeSpent: timeSpent)

        if var puzzle = currentPuzzle {
            puzzle.hintsUsed += 1
            currentPuzzle = puzzle
        }

        coachComment = coach.variationComment(move: move, expectedMove: solutionMoves[currentSolutionIndex], isCorrect: false)

        if var session = session {
            session.puzzlesAttempted += 1
            self.session = session
        }

        // Reset to puzzle start after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let puzzle = self.currentPuzzle {
                self.loadPuzzle(puzzle)
            }
            self.puzzleState = .waitingForMove
            // loadPuzzle clears the banner -- restore it so the player is
            // clearly told the attempt was wrong, not just silently reset.
            self.coachComment = "❌ Not correct. The board has been reset — try again."
        }
    }

    /// Moves on to the next puzzle in the session (or completes it if this
    /// was the last one). Called automatically 2s after solving a puzzle,
    /// and directly by the always-visible "Next Puzzle" button so the player
    /// is never stuck waiting on a silent timer or dead-ended after viewing
    /// a solution.
    func advanceToNextPuzzle() {
        guard !isAdvancing else { return }
        isAdvancing = true
        guard var session = session else { return }

        let allPuzzles = session.warmupPuzzles + session.mainPuzzles
        let prevIndex = session.currentPuzzleIndex

        // Record per-theme result for the puzzle we just finished
        if prevIndex < allPuzzles.count {
            let theme = allPuzzles[prevIndex].theme
            let key = theme.rawValue
            let wasSolved = solvedPuzzleIndices.contains(prevIndex)
            if session.themeResults[key] == nil {
                session.themeResults[key] = ThemeSessionResult()
            }
            session.themeResults[key]!.attempts += 1
            if wasSolved { session.themeResults[key]!.solved += 1 }
        }

        let nextIndex = prevIndex + 1
        if nextIndex < allPuzzles.count {
            session.currentPuzzleIndex = nextIndex
            self.session = session
            loadPuzzle(allPuzzles[nextIndex])
        } else {
            self.session = session
            completeSession()
        }
    }

    private func completeSession() {
        if var session = session {
            session.endDate = Date()
            self.session = session
        }
        isSessionComplete = true
    }

    /// Actually reveals the solution: shows the full remaining line in real
    /// move notation ("1.Qh5+ Kd7 2.Qxf7#"), plays it out on the board, then
    /// auto-advances to the next puzzle so viewing a solution never dead-ends.
    func showSolution() {
        guard currentSolutionIndex < solutionMoves.count else { return }
        puzzleState = .showingSolution

        let remaining = Array(solutionMoves[currentSolutionIndex...])
        coachComment = "Solution: " + solutionLine(from: remaining, board: boardVM.game.board)

        if var session = session {
            session.puzzlesAttempted += 1
            self.session = session
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            for algebraic in remaining {
                try? await Task.sleep(nanoseconds: 700_000_000)
                let board = self.boardVM.game.board
                if let move = self.parseMove(algebraic, board: board) {
                    self.boardVM.executeMove(move)
                }
            }
            // Give the player ~45s to study the line and final position
            // before moving on (the "Next" button skips sooner at any time).
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            if self.puzzleState == .showingSolution {
                self.advanceToNextPuzzle()
            }
        }
    }

    /// Renders a UCI move list as a numbered SAN line ("1.Qh5+ Kd7 2.Qxf7#")
    /// by simulating the moves from the given position.
    private func solutionLine(from uciMoves: [String], board startBoard: ChessBoard) -> String {
        let engine = ChessEngineService.shared
        var board = startBoard
        var parts: [String] = []
        for uci in uciMoves {
            guard let move = engine.move(fromUCI: uci, board: board) else {
                parts.append(uci)
                break
            }
            let san = engine.san(move, on: board)
            // Figurine style: lead with the piece glyph. Crucially this gives
            // pawn moves a visible piece too ("♟e4" instead of a bare "e4",
            // which beginners often can't attribute to any piece).
            let display: String
            if move.isCastling {
                display = san
            } else if move.piece.type == .pawn {
                display = move.piece.symbolForColor + san
            } else {
                display = move.piece.symbolForColor + String(san.dropFirst())
            }
            if board.activeColor == .white {
                parts.append("\(board.fullMoveNumber).\(display)")
            } else if parts.isEmpty {
                parts.append("\(board.fullMoveNumber)...\(display)")
            } else {
                parts.append(display)
            }
            board = engine.applyMove(move, to: board)
        }
        return parts.joined(separator: " ")
    }

    /// Saves the current puzzle into "My Puzzles" so the player can practice
    /// it again later, independent of the session flow.
    func flagCurrentPuzzle() {
        guard let puzzle = currentPuzzle else { return }
        var copy = puzzle
        copy.attemptCount = 0
        copy.solvedCorrectly = false
        copy.timeSpent = 0
        copy.hintsUsed = 0
        let added = PersistenceService.shared.addPersonalPuzzles([copy])
        coachComment = added > 0 ? "⭐ Saved to My Puzzles for future practice."
                                 : "⭐ Already saved in My Puzzles."
    }

    func requestHint() {
        guard let puzzle = currentPuzzle, profile != nil else { return }
        let settings = AppSettings()
        hintText = coach.generateHint(for: puzzle, level: settings.hintLevel, board: boardVM.game.board)
        if var puzzle = currentPuzzle {
            puzzle.hintsUsed += 1
            currentPuzzle = puzzle
        }
    }

    private func calculateScore() -> Int {
        guard let puzzle = currentPuzzle else { return 0 }
        var score = 100
        score -= puzzle.hintsUsed * 20
        let time = Date().timeIntervalSince(puzzleStartTime)
        if time < 30 { score += 50 }
        else if time < 60 { score += 20 }
        return max(10, score)
    }

    var currentPuzzleProgress: Double {
        guard let session = session else { return 0 }
        let total = session.warmupPuzzles.count + session.mainPuzzles.count
        guard total > 0 else { return 0 }
        return Double(session.currentPuzzleIndex) / Double(total)
    }
}

// MARK: - Puzzle State
enum PuzzleState {
    case idle
    case waitingForMove
    case correct
    /// Cloud Stockfish is verifying whether an off-script move is engine-best.
    case checking
    case incorrect
    case solved
    case showingSolution
}
