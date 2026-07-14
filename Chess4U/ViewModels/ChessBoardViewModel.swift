import SwiftUI
import Combine

@MainActor
class ChessBoardViewModel: ObservableObject {
    @Published var game: ChessGame
    @Published var selectedSquare: Square? = nil
    @Published var legalMoveSquares: [Square] = []
    @Published var lastMove: ChessMove? = nil
    @Published var promotionPending: Square? = nil
    @Published var isFlipped: Bool = false
    @Published var highlightedSquares: [Square: Color] = [:]
    @Published var arrows: [(Square, Square)] = []
    @Published var coachInsight: CoachInsight? = nil
    @Published var animatingMove: ChessMove? = nil
    @Published var isAIThinking: Bool = false
    @Published var statusMessage: String = ""
    @Published var showHints: Bool = false

    private let engine = ChessEngineService.shared
    private let coach = AICoachService.shared
    private let adaptive = AdaptiveDifficultyService.shared
    var settings: AppSettings
    var profile: PlayerProfile?
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings = AppSettings(), profile: PlayerProfile? = nil) {
        self.game = ChessGame()
        self.settings = settings
        self.profile = profile
        self.isFlipped = settings.autoFlipBoard && (profile?.band == .bandE)
        updateStatusMessage()
    }

    init(fen: String, settings: AppSettings = AppSettings(), profile: PlayerProfile? = nil) {
        self.game = ChessGame(fen: fen)
        self.settings = settings
        self.profile = profile
        updateStatusMessage()
    }

    // MARK: - Square Selection
    func selectSquare(_ square: Square) {
        guard promotionPending == nil else { return }

        let board = game.board

        if let selected = selectedSquare {
            // Try to make a move
            if legalMoveSquares.contains(square), let selectedPiece = board[selected] {
                let movesFromSelected = engine.legalMoves(for: selectedPiece, at: selected, on: board)
                if let move = movesFromSelected.first(where: { $0.to == square }) {
                    if selectedPiece.type == .pawn {
                        let promotionRank = selectedPiece.color == .white ? 7 : 0
                        if square.rank == promotionRank {
                            promotionPending = square
                            return  // Keep selectedSquare for promotion handling
                        }
                    }
                    executeMove(move)
                    selectedSquare = nil
                    legalMoveSquares = []
                    return
                }
            }

            // Deselect or select new piece
            if let piece = board[square], piece.color == board.activeColor {
                selectedSquare = square
                legalMoveSquares = engine.legalMoves(for: piece, at: square, on: board).map { $0.to }
            } else {
                selectedSquare = nil
                legalMoveSquares = []
            }
        } else {
            // Select piece
            if let piece = board[square], piece.color == board.activeColor {
                selectedSquare = square
                legalMoveSquares = engine.legalMoves(for: piece, at: square, on: board).map { $0.to }
            }
        }
    }

    func executeMove(_ move: ChessMove) {
        withAnimation(.easeInOut(duration: 0.2)) {
            animatingMove = move
        }
        game.makeMove(move)
        lastMove = move
        updateStatusMessage()
        generateCoachInsight(for: move)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.animatingMove = nil
        }
    }

    func handlePromotion(piece: PieceType) {
        guard let fromSquare = selectedSquare,
              let toSquare = promotionPending,
              let movingPiece = game.board[fromSquare] else {
            promotionPending = nil
            selectedSquare = nil
            return
        }

        let board = game.board
        let allMoves = engine.legalMoves(for: movingPiece, at: fromSquare, on: board)
        if let move = allMoves.first(where: { $0.to == toSquare && $0.promotionPiece == piece }) {
            executeMove(move)
        }
        promotionPending = nil
        selectedSquare = nil
        legalMoveSquares = []
    }

    // MARK: - AI Move
    func makeAIMove(depth: Int = 3) {
        isAIThinking = true
        let board = game.board
        let color = board.activeColor
        let engine = self.engine  // capture before leaving MainActor context

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let move = engine.bestMove(for: color, on: board, depth: depth)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAIThinking = false
                if let move = move {
                    self.executeMove(move)
                }
            }
        }
    }

    // MARK: - Navigation
    func goToStart() {
        game = ChessGame()
        resetUI()
        updateStatusMessage()
    }

    func undoLastMove() {
        guard !game.moves.isEmpty else { return }
        let moves = Array(game.moves.dropLast())
        game = ChessGame()
        for move in moves {
            game.makeMove(move)
        }
        lastMove = moves.last
        resetUI()
        updateStatusMessage()
    }

    private func resetUI() {
        selectedSquare = nil
        legalMoveSquares = []
        coachInsight = nil
        arrows = []
        highlightedSquares = [:]
        promotionPending = nil
    }

    private func updateStatusMessage() {
        switch game.status {
        case .active:
            statusMessage = "\(game.board.activeColor.rawValue.capitalized) to move"
        case .check:
            statusMessage = "⚠️ Check! \(game.board.activeColor.rawValue.capitalized) is in check."
        case .checkmate(let winner):
            statusMessage = "🏆 Checkmate! \(winner.rawValue.capitalized) wins!"
        case .stalemate:
            statusMessage = "🤝 Stalemate — Draw!"
        case .draw(let reason):
            statusMessage = "🤝 Draw by \(reason.rawValue)"
        case .resigned(let color):
            statusMessage = "\(color.rawValue.capitalized) resigned."
        }
    }

    private func generateCoachInsight(for move: ChessMove) {
        guard let profile = profile else { return }
        coachInsight = TreeOfThoughtEngine.shared.generateCoachInsight(
            for: move, board: game.board, profile: profile)
    }

    // MARK: - Board Display
    func squareColor(file: Int, rank: Int) -> Color {
        let isLight = (file + rank) % 2 == 1
        return isLight ? lightSquareColor : darkSquareColor
    }

    private var lightSquareColor: Color {
        switch settings.boardTheme {
        case .classic:    return Color(red: 0.95, green: 0.92, blue: 0.82)
        case .wood:       return Color(red: 0.95, green: 0.85, blue: 0.65)
        case .marble:     return Color(red: 0.93, green: 0.93, blue: 0.93)
        case .midnight:   return Color(red: 0.55, green: 0.65, blue: 0.75)
        case .tournament: return Color(red: 0.92, green: 0.92, blue: 0.86)
        case .coral:      return Color(red: 0.98, green: 0.85, blue: 0.80)
        case .chessCom:   return Color(red: 0.93, green: 0.91, blue: 0.83)
        }
    }

    private var darkSquareColor: Color {
        switch settings.boardTheme {
        case .classic:    return Color(red: 0.46, green: 0.59, blue: 0.34)
        case .wood:       return Color(red: 0.72, green: 0.53, blue: 0.33)
        case .marble:     return Color(red: 0.60, green: 0.60, blue: 0.60)
        case .midnight:   return Color(red: 0.25, green: 0.35, blue: 0.50)
        case .tournament: return Color(red: 0.50, green: 0.65, blue: 0.38)
        case .coral:      return Color(red: 0.80, green: 0.45, blue: 0.40)
        case .chessCom:   return Color(red: 0.40, green: 0.52, blue: 0.63)
        }
    }

    func isSelected(_ square: Square) -> Bool { selectedSquare == square }
    func isLegalMove(_ square: Square) -> Bool { legalMoveSquares.contains(square) }
    func isLastMove(_ square: Square) -> Bool {
        guard let last = lastMove else { return false }
        return last.from == square || last.to == square
    }

    /// Current position evaluation in pawns from White's perspective (+= white advantage).
    var currentEvaluation: Double {
        Double(engine.evaluate(board: game.board)) / 100.0
    }
}
