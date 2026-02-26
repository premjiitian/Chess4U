import Foundation

// MARK: - Chess Engine Service
final class ChessEngineService {
    static let shared = ChessEngineService()
    private init() {}

    // MARK: - Legal Move Generation
    func legalMoves(for color: PieceColor, on board: ChessBoard) -> [ChessMove] {
        var moves: [ChessMove] = []
        for (square, piece) in board.allSquares(for: color) {
            moves.append(contentsOf: legalMoves(for: piece, at: square, on: board))
        }
        return moves
    }

    func legalMoves(for piece: ChessPiece, at square: Square, on board: ChessBoard) -> [ChessMove] {
        let pseudoLegal = pseudoLegalMoves(for: piece, at: square, on: board)
        return pseudoLegal.filter { move in
            let newBoard = applyMove(move, to: board)
            return !isInCheck(board: newBoard, color: piece.color)
        }
    }

    private func pseudoLegalMoves(for piece: ChessPiece, at square: Square, on board: ChessBoard) -> [ChessMove] {
        switch piece.type {
        case .pawn:   return pawnMoves(piece: piece, from: square, on: board)
        case .knight: return knightMoves(piece: piece, from: square, on: board)
        case .bishop: return slidingMoves(piece: piece, from: square, on: board, directions: [(-1,-1),(-1,1),(1,-1),(1,1)])
        case .rook:   return slidingMoves(piece: piece, from: square, on: board, directions: [(0,1),(0,-1),(1,0),(-1,0)])
        case .queen:  return slidingMoves(piece: piece, from: square, on: board, directions: [(0,1),(0,-1),(1,0),(-1,0),(-1,-1),(-1,1),(1,-1),(1,1)])
        case .king:   return kingMoves(piece: piece, from: square, on: board)
        }
    }

    private func pawnMoves(piece: ChessPiece, from square: Square, on board: ChessBoard) -> [ChessMove] {
        var moves: [ChessMove] = []
        let direction = piece.color == .white ? 1 : -1
        let startRank = piece.color == .white ? 1 : 6
        let promotionRank = piece.color == .white ? 7 : 0

        // Forward move
        let oneStep = square.offset(file: 0, rank: direction)
        if oneStep.isValid && board[oneStep] == nil {
            if oneStep.rank == promotionRank {
                for promo in [PieceType.queen, .rook, .bishop, .knight] {
                    moves.append(ChessMove(from: square, to: oneStep, piece: piece, promotionPiece: promo, notation: ""))
                }
            } else {
                moves.append(ChessMove(from: square, to: oneStep, piece: piece, notation: ""))
                // Double move from starting rank
                if square.rank == startRank {
                    let twoStep = square.offset(file: 0, rank: direction * 2)
                    if twoStep.isValid && board[twoStep] == nil {
                        moves.append(ChessMove(from: square, to: twoStep, piece: piece, notation: ""))
                    }
                }
            }
        }

        // Captures
        for fileOffset in [-1, 1] {
            let captureSquare = square.offset(file: fileOffset, rank: direction)
            guard captureSquare.isValid else { continue }

            if let target = board[captureSquare], target.color == piece.color.opposite {
                if captureSquare.rank == promotionRank {
                    for promo in [PieceType.queen, .rook, .bishop, .knight] {
                        moves.append(ChessMove(from: square, to: captureSquare, piece: piece, capturedPiece: target, promotionPiece: promo, notation: ""))
                    }
                } else {
                    moves.append(ChessMove(from: square, to: captureSquare, piece: piece, capturedPiece: target, notation: ""))
                }
            }

            // En passant
            if let ep = board.enPassantSquare, ep == captureSquare {
                let capturedPawnSquare = Square(captureSquare.file, square.rank)
                let capturedPawn = board[capturedPawnSquare]
                moves.append(ChessMove(from: square, to: captureSquare, piece: piece, capturedPiece: capturedPawn, isEnPassant: true, notation: ""))
            }
        }

        return moves
    }

    private func knightMoves(piece: ChessPiece, from square: Square, on board: ChessBoard) -> [ChessMove] {
        let offsets = [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)]
        return offsets.compactMap { (df, dr) in
            let to = square.offset(file: df, rank: dr)
            guard to.isValid else { return nil }
            let target = board[to]
            if let t = target, t.color == piece.color { return nil }
            return ChessMove(from: square, to: to, piece: piece, capturedPiece: target, notation: "")
        }
    }

    private func slidingMoves(piece: ChessPiece, from square: Square, on board: ChessBoard,
                               directions: [(Int, Int)]) -> [ChessMove] {
        var moves: [ChessMove] = []
        for (df, dr) in directions {
            var current = square.offset(file: df, rank: dr)
            while current.isValid {
                if let target = board[current] {
                    if target.color != piece.color {
                        moves.append(ChessMove(from: square, to: current, piece: piece, capturedPiece: target, notation: ""))
                    }
                    break
                }
                moves.append(ChessMove(from: square, to: current, piece: piece, notation: ""))
                current = current.offset(file: df, rank: dr)
            }
        }
        return moves
    }

    private func kingMoves(piece: ChessPiece, from square: Square, on board: ChessBoard) -> [ChessMove] {
        var moves: [ChessMove] = []
        let offsets = [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]
        for (df, dr) in offsets {
            let to = square.offset(file: df, rank: dr)
            guard to.isValid else { continue }
            let target = board[to]
            if let t = target, t.color == piece.color { continue }
            moves.append(ChessMove(from: square, to: to, piece: piece, capturedPiece: target, notation: ""))
        }

        // Castling
        if !piece.hasMoved && !isInCheck(board: board, color: piece.color) {
            let backRank = piece.color == .white ? 0 : 7
            // Kingside
            if (piece.color == .white ? board.castlingRights.whiteKingside : board.castlingRights.blackKingside) {
                let rookSquare = Square(7, backRank)
                if let rook = board[rookSquare], rook.type == .rook, !rook.hasMoved {
                    let f1 = Square(5, backRank), g1 = Square(6, backRank)
                    if board[f1] == nil && board[g1] == nil &&
                       !isAttacked(square: f1, by: piece.color.opposite, on: board) &&
                       !isAttacked(square: g1, by: piece.color.opposite, on: board) {
                        moves.append(ChessMove(from: square, to: g1, piece: piece, isCastling: true, notation: "O-O"))
                    }
                }
            }
            // Queenside
            if (piece.color == .white ? board.castlingRights.whiteQueenside : board.castlingRights.blackQueenside) {
                let rookSquare = Square(0, backRank)
                if let rook = board[rookSquare], rook.type == .rook, !rook.hasMoved {
                    let d1 = Square(3, backRank), c1 = Square(2, backRank), b1 = Square(1, backRank)
                    if board[d1] == nil && board[c1] == nil && board[b1] == nil &&
                       !isAttacked(square: d1, by: piece.color.opposite, on: board) &&
                       !isAttacked(square: c1, by: piece.color.opposite, on: board) {
                        moves.append(ChessMove(from: square, to: c1, piece: piece, isCastling: true, notation: "O-O-O"))
                    }
                }
            }
        }
        return moves
    }

    // MARK: - Apply Move
    func applyMove(_ move: ChessMove, to board: ChessBoard) -> ChessBoard {
        var newBoard = board
        var piece = move.piece
        piece.hasMoved = true

        newBoard[move.from] = nil
        newBoard[move.to] = piece

        // En passant capture
        if move.isEnPassant {
            let capturedPawnSquare = Square(move.to.file, move.from.rank)
            newBoard[capturedPawnSquare] = nil
        }

        // Promotion
        if let promoType = move.promotionPiece {
            newBoard[move.to] = ChessPiece(type: promoType, color: piece.color, hasMoved: true)
        }

        // Castling — move rook
        if move.isCastling {
            let backRank = piece.color == .white ? 0 : 7
            if move.to.file == 6 {  // Kingside
                let rookFrom = Square(7, backRank)
                if var rook = newBoard[rookFrom] {
                    rook.hasMoved = true
                    newBoard[Square(5, backRank)] = rook
                    newBoard[rookFrom] = nil
                }
            } else {  // Queenside
                let rookFrom = Square(0, backRank)
                if var rook = newBoard[rookFrom] {
                    rook.hasMoved = true
                    newBoard[Square(3, backRank)] = rook
                    newBoard[rookFrom] = nil
                }
            }
            // Update castling rights
            if piece.color == .white {
                newBoard.castlingRights.whiteKingside = false
                newBoard.castlingRights.whiteQueenside = false
            } else {
                newBoard.castlingRights.blackKingside = false
                newBoard.castlingRights.blackQueenside = false
            }
        }

        // Update castling rights for king/rook moves
        if move.piece.type == .king {
            if piece.color == .white {
                newBoard.castlingRights.whiteKingside = false
                newBoard.castlingRights.whiteQueenside = false
            } else {
                newBoard.castlingRights.blackKingside = false
                newBoard.castlingRights.blackQueenside = false
            }
        }
        if move.piece.type == .rook {
            let backRank = piece.color == .white ? 0 : 7
            if move.from == Square(7, backRank) {
                if piece.color == .white { newBoard.castlingRights.whiteKingside = false }
                else { newBoard.castlingRights.blackKingside = false }
            } else if move.from == Square(0, backRank) {
                if piece.color == .white { newBoard.castlingRights.whiteQueenside = false }
                else { newBoard.castlingRights.blackQueenside = false }
            }
        }

        // Update en passant square
        if move.piece.type == .pawn && abs(move.to.rank - move.from.rank) == 2 {
            let epRank = (move.from.rank + move.to.rank) / 2
            newBoard.enPassantSquare = Square(move.from.file, epRank)
        } else {
            newBoard.enPassantSquare = nil
        }

        // Update clocks
        newBoard.halfMoveClock = (move.isCapture || move.piece.type == .pawn) ? 0 : board.halfMoveClock + 1
        if board.activeColor == .black { newBoard.fullMoveNumber += 1 }
        newBoard.activeColor = board.activeColor.opposite

        return newBoard
    }

    // MARK: - Check Detection
    func isInCheck(board: ChessBoard, color: PieceColor) -> Bool {
        guard let kingSquare = board.kingSquare(for: color) else { return false }
        return isAttacked(square: kingSquare, by: color.opposite, on: board)
    }

    func isAttacked(square: Square, by attackerColor: PieceColor, on board: ChessBoard) -> Bool {
        for (attackerSquare, attacker) in board.allSquares(for: attackerColor) {
            let pMoves = pseudoLegalMoves(for: attacker, at: attackerSquare, on: board)
            if pMoves.contains(where: { $0.to == square }) { return true }
        }
        return false
    }

    // MARK: - Notation Generation
    func generateNotation(_ move: ChessMove, on board: ChessBoard) -> String {
        if move.isCastling {
            return move.to.file == 6 ? "O-O" : "O-O-O"
        }

        var notation = ""
        let piece = move.piece

        if piece.type != .pawn {
            notation += piece.type.symbol.uppercased()
        }

        if move.isCapture {
            if piece.type == .pawn {
                notation += String("abcdefgh"[String.Index(utf16Offset: move.from.file, in: "abcdefgh")])
            }
            notation += "x"
        }

        notation += move.to.algebraic

        if let promo = move.promotionPiece {
            notation += "=\(promo.symbol.uppercased())"
        }

        if let annotation = move.annotation {
            notation += annotation.icon
        }

        return notation
    }

    // MARK: - Position Evaluation
    func evaluate(board: ChessBoard) -> Int {
        var score = 0
        let pieceValues = [PieceType.pawn: 100, .knight: 320, .bishop: 330,
                           .rook: 500, .queen: 900, .king: 20000]

        for f in 0...7 {
            for r in 0...7 {
                guard let piece = board.squares[f][r] else { continue }
                let value = pieceValues[piece.type] ?? 0
                let pst = pieceSquareBonus(piece: piece, file: f, rank: r)
                if piece.color == .white {
                    score += value + pst
                } else {
                    score -= value + pst
                }
            }
        }
        return score
    }

    private func pieceSquareBonus(piece: ChessPiece, file: Int, rank: Int) -> Int {
        let r = piece.color == .white ? rank : 7 - rank
        switch piece.type {
        case .pawn:
            let table = [
                [0,0,0,0,0,0,0,0],
                [50,50,50,50,50,50,50,50],
                [10,10,20,30,30,20,10,10],
                [5,5,10,25,25,10,5,5],
                [0,0,0,20,20,0,0,0],
                [5,-5,-10,0,0,-10,-5,5],
                [5,10,10,-20,-20,10,10,5],
                [0,0,0,0,0,0,0,0]
            ]
            return table[7-r][file]
        case .knight:
            let table = [
                [-50,-40,-30,-30,-30,-30,-40,-50],
                [-40,-20,0,0,0,0,-20,-40],
                [-30,0,10,15,15,10,0,-30],
                [-30,5,15,20,20,15,5,-30],
                [-30,0,15,20,20,15,0,-30],
                [-30,5,10,15,15,10,5,-30],
                [-40,-20,0,5,5,0,-20,-40],
                [-50,-40,-30,-30,-30,-30,-40,-50]
            ]
            return table[7-r][file]
        default:
            return 0
        }
    }

    // MARK: - Best Move Search (Minimax)
    func bestMove(for color: PieceColor, on board: ChessBoard, depth: Int = 3) -> ChessMove? {
        let moves = legalMoves(for: color, on: board)
        guard !moves.isEmpty else { return nil }

        var bestScore = color == .white ? Int.min : Int.max
        var bestMove: ChessMove? = nil

        for move in moves {
            let newBoard = applyMove(move, to: board)
            let score = minimax(board: newBoard, depth: depth - 1,
                                alpha: Int.min, beta: Int.max,
                                maximizing: color == .black)
            if color == .white && score > bestScore {
                bestScore = score
                bestMove = move
            } else if color == .black && score < bestScore {
                bestScore = score
                bestMove = move
            }
        }
        return bestMove
    }

    private func minimax(board: ChessBoard, depth: Int, alpha: Int, beta: Int, maximizing: Bool) -> Int {
        if depth == 0 { return evaluate(board: board) }

        let color: PieceColor = maximizing ? .white : .black
        let moves = legalMoves(for: color, on: board)
        if moves.isEmpty {
            return isInCheck(board: board, color: color) ?
                   (maximizing ? -100000 : 100000) : 0
        }

        var alpha = alpha, beta = beta
        if maximizing {
            var maxScore = Int.min
            for move in moves {
                let newBoard = applyMove(move, to: board)
                let score = minimax(board: newBoard, depth: depth - 1, alpha: alpha, beta: beta, maximizing: false)
                maxScore = max(maxScore, score)
                alpha = max(alpha, score)
                if beta <= alpha { break }
            }
            return maxScore
        } else {
            var minScore = Int.max
            for move in moves {
                let newBoard = applyMove(move, to: board)
                let score = minimax(board: newBoard, depth: depth - 1, alpha: alpha, beta: beta, maximizing: true)
                minScore = min(minScore, score)
                beta = min(beta, score)
                if beta <= alpha { break }
            }
            return minScore
        }
    }
}
