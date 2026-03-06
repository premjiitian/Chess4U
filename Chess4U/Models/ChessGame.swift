import Foundation

// MARK: - Game Result
enum GameResult: String, Codable {
    case whiteWins = "1-0"
    case blackWins = "0-1"
    case draw = "1/2-1/2"
    case ongoing = "*"
}

// MARK: - Game Status
enum GameStatus: Codable, Equatable {
    case active
    case check
    case checkmate(PieceColor)
    case stalemate
    case draw(DrawReason)
    case resigned(PieceColor)
}

enum DrawReason: String, Codable, Equatable {
    case fiftyMoveRule = "50 Move Rule"
    case repetition = "Threefold Repetition"
    case insufficientMaterial = "Insufficient Material"
    case agreement = "Agreement"
}

// MARK: - Chess Game
class ChessGame: ObservableObject, Codable, @unchecked Sendable {
    var id: UUID = UUID()
    @Published var board: ChessBoard
    @Published var moves: [ChessMove] = []
    @Published var status: GameStatus = .active
    @Published var currentMoveIndex: Int = -1
    var positionHistory: [String] = []
    var whitePlayer: String
    var blackPlayer: String
    var startDate: Date
    var timeControl: TimeControl?
    var result: GameResult = .ongoing
    var moveTree: MoveTreeNode = MoveTreeNode()

    enum CodingKeys: String, CodingKey {
        case id, board, moves, status, whitePlayer, blackPlayer, startDate, result
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        board = try container.decode(ChessBoard.self, forKey: .board)
        moves = try container.decode([ChessMove].self, forKey: .moves)
        status = try container.decode(GameStatus.self, forKey: .status)
        whitePlayer = try container.decode(String.self, forKey: .whitePlayer)
        blackPlayer = try container.decode(String.self, forKey: .blackPlayer)
        startDate = try container.decode(Date.self, forKey: .startDate)
        result = try container.decode(GameResult.self, forKey: .result)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(board, forKey: .board)
        try container.encode(moves, forKey: .moves)
        try container.encode(status, forKey: .status)
        try container.encode(whitePlayer, forKey: .whitePlayer)
        try container.encode(blackPlayer, forKey: .blackPlayer)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(result, forKey: .result)
    }

    init(whitePlayer: String = "Player", blackPlayer: String = "AI Coach",
         timeControl: TimeControl? = nil) {
        self.board = ChessBoard()
        self.whitePlayer = whitePlayer
        self.blackPlayer = blackPlayer
        self.startDate = Date()
        self.timeControl = timeControl
        positionHistory.append(positionKey(for: board.fen))
    }

    init(fen: String, whitePlayer: String = "Player", blackPlayer: String = "AI Coach") {
        self.board = ChessBoard(fen: fen) ?? ChessBoard()
        self.whitePlayer = whitePlayer
        self.blackPlayer = blackPlayer
        self.startDate = Date()
        positionHistory.append(positionKey(for: board.fen))
    }

    var currentMove: Int { moves.count }
    var isWhiteTurn: Bool { board.activeColor == .white }

    func makeMove(_ move: ChessMove) {
        var updatedMove = move
        board = ChessEngineService.shared.applyMove(move, to: board)
        updatedMove.notation = ChessEngineService.shared.generateNotation(move, on: board)
        moves.append(updatedMove)
        currentMoveIndex = moves.count - 1
        positionHistory.append(positionKey(for: board.fen))
        updateStatus()
    }

    private func updateStatus() {
        let engine = ChessEngineService.shared
        if engine.isInCheck(board: board, color: board.activeColor) {
            let legalMoves = engine.legalMoves(for: board.activeColor, on: board)
            status = legalMoves.isEmpty ? .checkmate(board.activeColor.opposite) : .check
        } else {
            let legalMoves = engine.legalMoves(for: board.activeColor, on: board)
            if legalMoves.isEmpty {
                status = .stalemate
            } else if board.halfMoveClock >= 100 {
                status = .draw(.fiftyMoveRule)
            } else if isThreefoldRepetition() {
                status = .draw(.repetition)
            } else {
                status = .active
            }
        }

        if case .checkmate(let winner) = status {
            result = winner == .white ? .whiteWins : .blackWins
        } else if case .stalemate = status {
            result = .draw
        } else if case .draw = status {
            result = .draw
        }
    }

    /// Position key: first 4 FEN fields (piece placement, active color, castling, en-passant).
    /// Excludes the half-move clock and full-move number so that the same position reached
    /// via different move counts is still recognised as a repetition.
    private func positionKey(for fen: String) -> String {
        fen.split(separator: " ").prefix(4).joined(separator: " ")
    }

    private func isThreefoldRepetition() -> Bool {
        let current = positionKey(for: board.fen)
        let count = positionHistory.filter { $0 == current }.count
        return count >= 3
    }

    var pgnHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return """
        [White "\(whitePlayer)"]
        [Black "\(blackPlayer)"]
        [Date "\(formatter.string(from: startDate))"]
        [Result "\(result.rawValue)"]
        """
    }

    /// Full PGN string including header and move list.
    var pgn: String {
        var lines = [pgnHeader, ""]
        var moveText = ""
        for (idx, move) in moves.enumerated() {
            if idx % 2 == 0 {
                moveText += "\(idx / 2 + 1). "
            }
            let notation = move.notation.isEmpty ? move.longAlgebraic : move.notation
            moveText += notation + " "
        }
        moveText += result.rawValue
        // Wrap at ~80 chars for readability
        var line = ""
        for token in moveText.split(separator: " ") {
            let word = String(token)
            if line.count + word.count + 1 > 80 {
                lines.append(line)
                line = word
            } else {
                line += (line.isEmpty ? "" : " ") + word
            }
        }
        if !line.isEmpty { lines.append(line) }
        return lines.joined(separator: "\n")
    }
}
