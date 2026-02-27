import XCTest
@testable import Chess4U

final class ChessEngineTests: XCTestCase {

    let engine = ChessEngineService.shared

    // MARK: - Legal move counts from starting position

    func testLegalMoves_startingPosition_white_20() {
        // 16 pawn moves (8×2) + 4 knight moves = 20
        XCTAssertEqual(engine.legalMoves(for: .white, on: ChessBoard()).count, 20)
    }

    func testLegalMoves_startingPosition_black_20() {
        XCTAssertEqual(engine.legalMoves(for: .black, on: ChessBoard()).count, 20)
    }

    // MARK: - Pawn moves

    func testPawnMoves_fromStartRank_twoChoices() {
        let board = ChessBoard()
        let e2 = Square(4, 1)
        let pawn = board[e2]!
        let moves = engine.legalMoves(for: pawn, at: e2, on: board)
        XCTAssertEqual(moves.count, 2)
        XCTAssertTrue(moves.contains { $0.to == Square(4, 2) })  // e3
        XCTAssertTrue(moves.contains { $0.to == Square(4, 3) })  // e4
    }

    func testPawnMoves_blockedByFriendly() {
        var board = ChessBoard()
        // Blocking white e2 pawn with a black pawn on e3
        board[Square(4, 2)] = ChessPiece(type: .pawn, color: .black)
        let e2 = Square(4, 1)
        let pawn = board[e2]!
        XCTAssertEqual(engine.legalMoves(for: pawn, at: e2, on: board).count, 0)
    }

    // MARK: - Knight moves

    func testKnightMoves_fromCenter_8moves() {
        var board = ChessBoard()
        for f in 0...7 { for r in 0...7 { board[Square(f, r)] = nil } }
        let d4 = Square(3, 3)
        let knight = ChessPiece(type: .knight, color: .white)
        board[d4] = knight
        XCTAssertEqual(engine.legalMoves(for: knight, at: d4, on: board).count, 8)
    }

    func testKnightMoves_fromCorner_2moves() {
        var board = ChessBoard()
        for f in 0...7 { for r in 0...7 { board[Square(f, r)] = nil } }
        let a1 = Square(0, 0)
        let knight = ChessPiece(type: .knight, color: .white)
        board[a1] = knight
        let moves = engine.legalMoves(for: knight, at: a1, on: board)
        XCTAssertEqual(moves.count, 2)
        XCTAssertTrue(moves.contains { $0.to == Square(1, 2) })  // b3
        XCTAssertTrue(moves.contains { $0.to == Square(2, 1) })  // c2
    }

    // MARK: - Check detection

    func testIsInCheck_startingPosition_notInCheck() {
        let board = ChessBoard()
        XCTAssertFalse(engine.isInCheck(board: board, color: .white))
        XCTAssertFalse(engine.isInCheck(board: board, color: .black))
    }

    func testIsInCheck_foolsMate_whiteInCheck() {
        // After 1.f3 e5 2.g4 Qh4# — white king checked by queen on h4
        let fen = "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        XCTAssertTrue(engine.isInCheck(board: board, color: .white))
        XCTAssertFalse(engine.isInCheck(board: board, color: .black))
    }

    // MARK: - applyMove

    func testApplyMove_togglesActiveColor() {
        let board = ChessBoard()
        let pawn = board[Square(4, 1)]!
        let move = ChessMove(from: Square(4, 1), to: Square(4, 3), piece: pawn)
        let newBoard = engine.applyMove(move, to: board)
        XCTAssertEqual(newBoard.activeColor, .black)
    }

    func testApplyMove_movesPiece() {
        let board = ChessBoard()
        let pawn = board[Square(4, 1)]!
        let move = ChessMove(from: Square(4, 1), to: Square(4, 3), piece: pawn)
        let newBoard = engine.applyMove(move, to: board)
        XCTAssertNil(newBoard[Square(4, 1)])
        XCTAssertEqual(newBoard[Square(4, 3)]?.type, .pawn)
        XCTAssertEqual(newBoard[Square(4, 3)]?.color, .white)
    }

    func testApplyMove_capture_removesTarget() {
        // After 1.e4 d5 — white plays exd5
        let fen = "rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let whitePawn = board[Square(4, 3)]!
        let blackPawn = board[Square(3, 4)]!
        let capture = ChessMove(from: Square(4, 3), to: Square(3, 4),
                                piece: whitePawn, capturedPiece: blackPawn)
        let newBoard = engine.applyMove(capture, to: board)
        XCTAssertNil(newBoard[Square(4, 3)])
        XCTAssertEqual(newBoard[Square(3, 4)]?.color, .white)
    }

    func testApplyMove_incrementsFullMoveAfterBlack() {
        let fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let pawn = board[Square(4, 6)]!
        let move = ChessMove(from: Square(4, 6), to: Square(4, 4), piece: pawn)
        let newBoard = engine.applyMove(move, to: board)
        XCTAssertEqual(newBoard.fullMoveNumber, 2)
    }

    func testApplyMove_halfMoveClock_resetOnCapture() {
        let fen = "rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 5 2"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let whitePawn = board[Square(4, 3)]!
        let blackPawn = board[Square(3, 4)]!
        let capture = ChessMove(from: Square(4, 3), to: Square(3, 4),
                                piece: whitePawn, capturedPiece: blackPawn)
        let newBoard = engine.applyMove(capture, to: board)
        XCTAssertEqual(newBoard.halfMoveClock, 0)
    }

    // MARK: - Castling

    func testCastling_kingsideIncludedWhenLegal() {
        // Italian game — f1, g1 clear, king not moved, not in check
        let fen = "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let moves = engine.legalMoves(for: .white, on: board)
        XCTAssertTrue(moves.contains { $0.isCastling && $0.to == Square(6, 0) })  // O-O
    }

    func testCastling_notAvailableAfterRookMove() {
        let fen = "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4"
        guard var board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        board.castlingRights.whiteKingside = false
        let moves = engine.legalMoves(for: .white, on: board)
        XCTAssertFalse(moves.contains { $0.isCastling && $0.to == Square(6, 0) })
    }

    // MARK: - En passant

    func testEnPassant_squareSetAfterDoublePush() {
        let board = ChessBoard()
        let pawn = board[Square(4, 1)]!
        let move = ChessMove(from: Square(4, 1), to: Square(4, 3), piece: pawn)
        let newBoard = engine.applyMove(move, to: board)
        XCTAssertEqual(newBoard.enPassantSquare, Square(4, 2))  // e3
    }

    func testEnPassant_squareClearedAfterNextMove() {
        let board = ChessBoard()
        let wPawn = board[Square(4, 1)]!
        let move1 = ChessMove(from: Square(4, 1), to: Square(4, 3), piece: wPawn)
        let board2 = engine.applyMove(move1, to: board)
        let bPawn = board2[Square(0, 6)]!
        let move2 = ChessMove(from: Square(0, 6), to: Square(0, 5), piece: bPawn)
        let board3 = engine.applyMove(move2, to: board2)
        XCTAssertNil(board3.enPassantSquare)
    }
}
