import Foundation

// MARK: - Chess Board State
struct ChessBoard: Codable, Equatable {
    var squares: [[ChessPiece?]]  // [file][rank]
    var activeColor: PieceColor
    var castlingRights: CastlingRights
    var enPassantSquare: Square?
    var halfMoveClock: Int
    var fullMoveNumber: Int

    static let startingFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    init() {
        squares = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        activeColor = .white
        castlingRights = CastlingRights()
        enPassantSquare = nil
        halfMoveClock = 0
        fullMoveNumber = 1
        setupStartingPosition()
    }

    init?(fen: String) {
        squares = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        activeColor = .white
        castlingRights = CastlingRights()
        enPassantSquare = nil
        halfMoveClock = 0
        fullMoveNumber = 1
        guard parseFEN(fen) else { return nil }
    }

    subscript(square: Square) -> ChessPiece? {
        get { squares[square.file][square.rank] }
        set { squares[square.file][square.rank] = newValue }
    }

    mutating func setupStartingPosition() {
        // Black pieces (rank 7)
        self[Square(0, 7)] = ChessPiece(type: .rook, color: .black)
        self[Square(1, 7)] = ChessPiece(type: .knight, color: .black)
        self[Square(2, 7)] = ChessPiece(type: .bishop, color: .black)
        self[Square(3, 7)] = ChessPiece(type: .queen, color: .black)
        self[Square(4, 7)] = ChessPiece(type: .king, color: .black)
        self[Square(5, 7)] = ChessPiece(type: .bishop, color: .black)
        self[Square(6, 7)] = ChessPiece(type: .knight, color: .black)
        self[Square(7, 7)] = ChessPiece(type: .rook, color: .black)
        for f in 0...7 { self[Square(f, 6)] = ChessPiece(type: .pawn, color: .black) }

        // White pieces (rank 0)
        self[Square(0, 0)] = ChessPiece(type: .rook, color: .white)
        self[Square(1, 0)] = ChessPiece(type: .knight, color: .white)
        self[Square(2, 0)] = ChessPiece(type: .bishop, color: .white)
        self[Square(3, 0)] = ChessPiece(type: .queen, color: .white)
        self[Square(4, 0)] = ChessPiece(type: .king, color: .white)
        self[Square(5, 0)] = ChessPiece(type: .bishop, color: .white)
        self[Square(6, 0)] = ChessPiece(type: .knight, color: .white)
        self[Square(7, 0)] = ChessPiece(type: .rook, color: .white)
        for f in 0...7 { self[Square(f, 1)] = ChessPiece(type: .pawn, color: .white) }
    }

    @discardableResult
    mutating func parseFEN(_ fen: String) -> Bool {
        let parts = fen.split(separator: " ")
        guard parts.count >= 4 else { return false }

        // Parse piece placement
        let ranks = parts[0].split(separator: "/")
        guard ranks.count == 8 else { return false }

        for (rankIdx, rankStr) in ranks.reversed().enumerated() {
            var fileIdx = 0
            for char in rankStr {
                if let emptyCount = char.wholeNumberValue {
                    fileIdx += emptyCount
                } else {
                    let color: PieceColor = char.isUppercase ? .white : .black
                    let pieceType: PieceType?
                    switch char.lowercased() {
                    case "k": pieceType = .king
                    case "q": pieceType = .queen
                    case "r": pieceType = .rook
                    case "b": pieceType = .bishop
                    case "n": pieceType = .knight
                    case "p": pieceType = .pawn
                    default:  pieceType = nil
                    }
                    if let type = pieceType, fileIdx < 8 {
                        squares[fileIdx][rankIdx] = ChessPiece(type: type, color: color)
                        fileIdx += 1
                    }
                }
            }
        }

        // Active color
        activeColor = parts[1] == "w" ? .white : .black

        // Castling rights
        let castling = String(parts[2])
        castlingRights = CastlingRights(
            whiteKingside: castling.contains("K"),
            whiteQueenside: castling.contains("Q"),
            blackKingside: castling.contains("k"),
            blackQueenside: castling.contains("q")
        )

        // En passant
        enPassantSquare = parts[3] == "-" ? nil : Square(algebraic: String(parts[3]))

        // Clocks
        if parts.count > 4, let halfMove = Int(parts[4]) { halfMoveClock = halfMove }
        if parts.count > 5, let fullMove = Int(parts[5]) { fullMoveNumber = fullMove }

        return true
    }

    var fen: String {
        var fen = ""
        for rank in stride(from: 7, through: 0, by: -1) {
            var empty = 0
            for file in 0...7 {
                if let piece = squares[file][rank] {
                    if empty > 0 { fen += "\(empty)"; empty = 0 }
                    let char = piece.type.fenChar
                    fen += piece.color == .white ? char.uppercased() : String(char)
                } else {
                    empty += 1
                }
            }
            if empty > 0 { fen += "\(empty)" }
            if rank > 0 { fen += "/" }
        }
        fen += " \(activeColor == .white ? "w" : "b")"
        let castling = castlingRights.fenString
        fen += " \(castling.isEmpty ? "-" : castling)"
        fen += " \(enPassantSquare?.algebraic ?? "-")"
        fen += " \(halfMoveClock) \(fullMoveNumber)"
        return fen
    }

    func piece(at square: Square) -> ChessPiece? {
        guard square.isValid else { return nil }
        return squares[square.file][square.rank]
    }

    func kingSquare(for color: PieceColor) -> Square? {
        for f in 0...7 {
            for r in 0...7 {
                let sq = Square(f, r)
                if let piece = self[sq], piece.type == .king, piece.color == color {
                    return sq
                }
            }
        }
        return nil
    }

    func allSquares(for color: PieceColor) -> [(Square, ChessPiece)] {
        var result: [(Square, ChessPiece)] = []
        for f in 0...7 {
            for r in 0...7 {
                let sq = Square(f, r)
                if let piece = self[sq], piece.color == color {
                    result.append((sq, piece))
                }
            }
        }
        return result
    }

    var materialBalance: Int {
        var balance = 0
        for f in 0...7 {
            for r in 0...7 {
                if let piece = squares[f][r] {
                    let value = piece.type.value
                    balance += piece.color == .white ? value : -value
                }
            }
        }
        return balance
    }
}

// MARK: - Castling Rights
struct CastlingRights: Codable, Equatable {
    var whiteKingside: Bool = true
    var whiteQueenside: Bool = true
    var blackKingside: Bool = true
    var blackQueenside: Bool = true

    var fenString: String {
        var s = ""
        if whiteKingside { s += "K" }
        if whiteQueenside { s += "Q" }
        if blackKingside { s += "k" }
        if blackQueenside { s += "q" }
        return s
    }
}
