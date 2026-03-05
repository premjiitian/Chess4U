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
        session = thoughtEngine.generateSession(type: type, profile: profile)
        showLesson = session?.conceptLesson != nil
        isSessionComplete = false
        sessionScore = 0

        if let firstPuzzle = session?.warmupPuzzles.first {
            loadPuzzle(firstPuzzle)
        }
    }

    // MARK: - Load Puzzle
    func loadPuzzle(_ puzzle: ChessPuzzle) {
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
        guard currentPuzzle != nil, puzzleState == .waitingForMove else { return }

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
            handleIncorrectMove(move)
        }
    }

    private func makeOpponentMove() {
        guard currentSolutionIndex < solutionMoves.count else { return }
        let opponentMove = solutionMoves[currentSolutionIndex]
        // Apply the scripted opponent move
        let board = boardVM.game.board
        if let sq = parseMove(opponentMove, board: board) {
            boardVM.executeMove(sq)
            currentSolutionIndex += 1
        }
    }

    private func parseMove(_ algebraic: String, board: ChessBoard) -> ChessMove? {
        guard algebraic.count >= 4 else { return nil }
        let fromStr = String(algebraic.prefix(2))
        let toStr = String(algebraic.dropFirst(2).prefix(2))
        guard let from = Square(algebraic: fromStr),
              let to = Square(algebraic: toStr),
              let piece = board[from] else { return nil }

        let promotion: PieceType? = algebraic.count == 5 ? {
            switch algebraic.last {
            case "q": return .queen
            case "r": return .rook
            case "b": return .bishop
            case "n": return .knight
            default: return nil
            }
        }() : nil

        let engine = ChessEngineService.shared
        let legalMoves = engine.legalMoves(for: piece, at: from, on: board)
        return legalMoves.first { $0.to == to && ($0.promotionPiece == promotion || promotion == nil) }
    }

    private func handlePuzzleSolved() {
        puzzleState = .solved
        let timeSpent = Date().timeIntervalSince(puzzleStartTime)
        adaptive.recordResult(correct: true, timeSpent: timeSpent)

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
        }
    }

    private func advanceToNextPuzzle() {
        guard var session = session else { return }

        let allPuzzles = session.warmupPuzzles + session.mainPuzzles
        let nextIndex = session.currentPuzzleIndex + 1

        if nextIndex < allPuzzles.count {
            session.currentPuzzleIndex = nextIndex
            self.session = session
            loadPuzzle(allPuzzles[nextIndex])
        } else {
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
    case incorrect
    case solved
    case showingSolution
}
