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

    // MARK: - Sliding piece move counts (rook / bishop / queen)

    func testRookMoves_fromD4_onEmptyBoard_14() {
        var board = ChessBoard()
        for f in 0...7 { for r in 0...7 { board[Square(f, r)] = nil } }
        let d4 = Square(3, 3)
        let rook = ChessPiece(type: .rook, color: .white)
        board[d4] = rook
        // No king → isInCheck guard returns false, all pseudo-legal moves are legal
        XCTAssertEqual(engine.legalMoves(for: rook, at: d4, on: board).count, 14)
    }

    func testBishopMoves_fromE4_onEmptyBoard_13() {
        var board = ChessBoard()
        for f in 0...7 { for r in 0...7 { board[Square(f, r)] = nil } }
        let e4 = Square(4, 3)
        let bishop = ChessPiece(type: .bishop, color: .white)
        board[e4] = bishop
        XCTAssertEqual(engine.legalMoves(for: bishop, at: e4, on: board).count, 13)
    }

    func testQueenMoves_fromD4_onEmptyBoard_27() {
        var board = ChessBoard()
        for f in 0...7 { for r in 0...7 { board[Square(f, r)] = nil } }
        let d4 = Square(3, 3)
        let queen = ChessPiece(type: .queen, color: .white)
        board[d4] = queen
        XCTAssertEqual(engine.legalMoves(for: queen, at: d4, on: board).count, 27)
    }

    // MARK: - Pawn diagonal capture

    func testPawnCapture_diagonal() {
        // White pawn on d4, black pawn on e5 — white can advance to d5 or capture on e5
        let fen = "7k/8/8/4p3/3P4/8/8/K7 w - - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let d4 = Square(3, 3)
        let pawn = board[d4]!
        let moves = engine.legalMoves(for: pawn, at: d4, on: board)
        XCTAssertEqual(moves.count, 2)
        XCTAssertTrue(moves.contains { $0.to == Square(4, 4) && $0.isCapture })  // dxe5
        XCTAssertTrue(moves.contains { $0.to == Square(3, 4) && !$0.isCapture }) // d5
    }

    // MARK: - En passant capture execution

    func testEnPassant_capturedPawnRemovedFromBoard() {
        // White pawn d5 captures en passant on e6; black pawn on e5 must vanish
        let fen = "7k/8/8/3Pp3/8/8/8/K7 w - e6 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let d5 = Square(3, 4)
        let pawn = board[d5]!
        let moves = engine.legalMoves(for: pawn, at: d5, on: board)
        guard let epMove = moves.first(where: { $0.isEnPassant }) else {
            XCTFail("En passant move not generated"); return
        }
        let newBoard = engine.applyMove(epMove, to: board)
        XCTAssertNil(newBoard[Square(4, 4)])          // black pawn on e5 removed
        XCTAssertNotNil(newBoard[Square(4, 5)])        // white pawn landed on e6
        XCTAssertNil(newBoard[Square(3, 4)])           // original d5 square cleared
    }

    // MARK: - Pawn promotion

    func testPawnPromotion_generatesAllFourPieces() {
        // White pawn on e7, clear path to e8
        let fen = "7k/4P3/8/8/8/8/8/K7 w - - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let e7 = Square(4, 6)
        let pawn = board[e7]!
        let moves = engine.legalMoves(for: pawn, at: e7, on: board)
        let promoMoves = moves.filter { $0.promotionPiece != nil }
        XCTAssertEqual(promoMoves.count, 4)
        let promoTypes = Set(promoMoves.compactMap { $0.promotionPiece })
        XCTAssertEqual(promoTypes, [.queen, .rook, .bishop, .knight])
    }

    // MARK: - King cannot move into check

    func testKing_cannotMoveIntoCheck() {
        // White king a1, black rook c1 — b1 is controlled; only a2 and b2 are safe
        let fen = "k7/8/8/8/8/8/8/K1r5 w - - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let a1 = Square(0, 0)
        let king = board[a1]!
        let moves = engine.legalMoves(for: king, at: a1, on: board)
        XCTAssertFalse(moves.contains { $0.to == Square(1, 0) })  // b1 attacked by rook
        XCTAssertTrue(moves.contains { $0.to == Square(0, 1) })   // a2 safe
        XCTAssertTrue(moves.contains { $0.to == Square(1, 1) })   // b2 safe
    }

    // MARK: - Pinned piece

    func testPinnedRook_canOnlyMoveAlongPinLine() {
        // White Ke1, Re4 pinned along e-file by black Re8
        let fen = "4r3/8/8/8/4R3/8/8/4K3 w - - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let e4 = Square(4, 3)
        let rook = board[e4]!
        let moves = engine.legalMoves(for: rook, at: e4, on: board)
        // Pinned rook may only stay on the e-file (e2, e3, e5, e6, e7, xe8)
        XCTAssertEqual(moves.count, 6)
        XCTAssertTrue(moves.allSatisfy { $0.to.file == 4 })  // all on e-file
    }

    // MARK: - Queenside castling

    func testCastling_queensideIncludedWhenLegal() {
        // White: Ra1, Ke1 — b1/c1/d1 clear, queenside rights set
        let fen = "4k3/8/8/8/8/8/8/R3K3 w Q - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let moves = engine.legalMoves(for: .white, on: board)
        XCTAssertTrue(moves.contains { $0.isCastling && $0.to == Square(2, 0) })  // O-O-O
    }

    func testCastling_notAvailableWhenInCheck() {
        // Black rook on e8 gives check — you cannot castle out of check
        let fen = "4r2k/8/8/8/8/8/8/R3K2R w KQ - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        XCTAssertTrue(engine.isInCheck(board: board, color: .white))
        let moves = engine.legalMoves(for: .white, on: board)
        XCTAssertFalse(moves.contains { $0.isCastling })
    }

    func testCastling_notAvailableWhenPathAttacked() {
        // Black rook f8 controls f1 — king cannot pass through f1 for O-O
        let fen = "5rk1/8/8/8/8/8/8/4K2R w K - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        XCTAssertFalse(engine.isInCheck(board: board, color: .white))  // not currently in check
        let moves = engine.legalMoves(for: .white, on: board)
        XCTAssertFalse(moves.contains { $0.isCastling && $0.to == Square(6, 0) })  // O-O blocked
    }

    // MARK: - Castling execution (rook placement)

    func testCastling_kingside_rookMovesToF1() {
        // Italian game — apply the O-O move and verify rook lands on f1
        let fen = "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let king = board[Square(4, 0)]!
        let move = ChessMove(from: Square(4, 0), to: Square(6, 0), piece: king, isCastling: true)
        let newBoard = engine.applyMove(move, to: board)
        XCTAssertEqual(newBoard[Square(6, 0)]?.type, .king)  // king on g1
        XCTAssertEqual(newBoard[Square(5, 0)]?.type, .rook)  // rook on f1
        XCTAssertNil(newBoard[Square(7, 0)])                  // h1 cleared
        XCTAssertNil(newBoard[Square(4, 0)])                  // e1 cleared
    }

    func testCastling_queenside_rookMovesToD1() {
        let fen = "4k3/8/8/8/8/8/8/R3K3 w Q - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let king = board[Square(4, 0)]!
        let move = ChessMove(from: Square(4, 0), to: Square(2, 0), piece: king, isCastling: true)
        let newBoard = engine.applyMove(move, to: board)
        XCTAssertEqual(newBoard[Square(2, 0)]?.type, .king)  // king on c1
        XCTAssertEqual(newBoard[Square(3, 0)]?.type, .rook)  // rook on d1
        XCTAssertNil(newBoard[Square(0, 0)])                  // a1 cleared
        XCTAssertNil(newBoard[Square(4, 0)])                  // e1 cleared
    }

    // MARK: - Promotion execution

    func testPromotion_applyMove_pieceTypeChanges() {
        let fen = "7k/4P3/8/8/8/8/8/K7 w - - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let pawn = board[Square(4, 6)]!
        let move = ChessMove(from: Square(4, 6), to: Square(4, 7),
                             piece: pawn, promotionPiece: .queen)
        let newBoard = engine.applyMove(move, to: board)
        XCTAssertEqual(newBoard[Square(4, 7)]?.type, .queen)   // promoted to queen on e8
        XCTAssertEqual(newBoard[Square(4, 7)]?.color, .white)
        XCTAssertNil(newBoard[Square(4, 6)])                    // e7 cleared
    }

    // MARK: - isAttacked direct tests

    func testIsAttacked_byBishop_diagonal() {
        var board = ChessBoard()
        for f in 0...7 { for r in 0...7 { board[Square(f, r)] = nil } }
        board[Square(2, 0)] = ChessPiece(type: .bishop, color: .white)  // Bc1
        XCTAssertTrue(engine.isAttacked(square: Square(4, 2), by: .white, on: board))   // e3 on diagonal
        XCTAssertFalse(engine.isAttacked(square: Square(4, 0), by: .white, on: board))  // e1 not diagonal
    }

    func testIsAttacked_byRook_blockedByPiece() {
        var board = ChessBoard()
        for f in 0...7 { for r in 0...7 { board[Square(f, r)] = nil } }
        board[Square(0, 0)] = ChessPiece(type: .rook, color: .black)   // Ra1 (black)
        board[Square(3, 0)] = ChessPiece(type: .pawn, color: .black)   // blocker on d1
        // e1 (4,0) is behind the blocker — rook cannot reach it
        XCTAssertFalse(engine.isAttacked(square: Square(4, 0), by: .black, on: board))
        // d1 (3,0) itself is not attacked (occupied by own piece, but that's the blocker)
        XCTAssertTrue(engine.isAttacked(square: Square(2, 0), by: .black, on: board))   // c1 is attacked
    }

    // MARK: - Checkmate and stalemate

    func testLegalMoves_checkmate_returnsEmpty() {
        // Fool's mate — white is in checkmate
        let fen = "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        XCTAssertTrue(engine.legalMoves(for: .white, on: board).isEmpty)
        XCTAssertTrue(engine.isInCheck(board: board, color: .white))
    }

    func testLegalMoves_stalemate_returnsEmpty() {
        // Black king a8, white queen c7, white king b6 — black has no legal moves, not in check
        let fen = "k7/2Q5/1K6/8/8/8/8/8 b - - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        XCTAssertTrue(engine.legalMoves(for: .black, on: board).isEmpty)
        XCTAssertFalse(engine.isInCheck(board: board, color: .black))
    }

    // MARK: - generateNotation

    func testGenerateNotation_kingsideCastling() {
        let board = ChessBoard()
        let king = board[Square(4, 0)]!
        let move = ChessMove(from: Square(4, 0), to: Square(6, 0), piece: king, isCastling: true)
        XCTAssertEqual(engine.generateNotation(move, on: board), "O-O")
    }

    func testGenerateNotation_queensideCastling() {
        let board = ChessBoard()
        let king = board[Square(4, 0)]!
        let move = ChessMove(from: Square(4, 0), to: Square(2, 0), piece: king, isCastling: true)
        XCTAssertEqual(engine.generateNotation(move, on: board), "O-O-O")
    }

    func testGenerateNotation_pawnMove() {
        let board = ChessBoard()
        let pawn = board[Square(4, 1)]!  // e2 pawn
        let move = ChessMove(from: Square(4, 1), to: Square(4, 3), piece: pawn)
        XCTAssertEqual(engine.generateNotation(move, on: board), "e4")
    }

    func testGenerateNotation_pieceMove() {
        let board = ChessBoard()
        let knight = board[Square(6, 0)]!  // g1 knight
        let move = ChessMove(from: Square(6, 0), to: Square(5, 2), piece: knight)
        // PieceType.knight.symbol is a unicode glyph; uppercased() preserves it
        let notation = engine.generateNotation(move, on: board)
        XCTAssertTrue(notation.hasSuffix("f3"))
        XCTAssertFalse(notation.hasPrefix("f"))  // piece prefix present
    }

    func testGenerateNotation_pawnCapture() {
        // White pawn e4 captures on d5
        let fen = "rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let whitePawn = board[Square(4, 3)]!
        let blackPawn = board[Square(3, 4)]!
        let move = ChessMove(from: Square(4, 3), to: Square(3, 4),
                             piece: whitePawn, capturedPiece: blackPawn)
        XCTAssertEqual(engine.generateNotation(move, on: board), "exd5")
    }

    func testGenerateNotation_promotion() {
        let fen = "7k/4P3/8/8/8/8/8/K7 w - - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let pawn = board[Square(4, 6)]!
        let move = ChessMove(from: Square(4, 6), to: Square(4, 7),
                             piece: pawn, promotionPiece: .queen)
        let notation = engine.generateNotation(move, on: board)
        XCTAssertTrue(notation.hasPrefix("e8"))
        XCTAssertTrue(notation.contains("="))
    }

    // MARK: - evaluate

    func testEvaluate_startingPosition_isZero() {
        // Symmetric position — white and black material/PST cancel exactly
        XCTAssertEqual(engine.evaluate(board: ChessBoard()), 0)
    }

    func testEvaluate_whiteMaterialAdvantage_isPositive() {
        var board = ChessBoard()
        board[Square(3, 7)] = nil  // remove black queen
        XCTAssertGreaterThan(engine.evaluate(board: board), 0)
    }

    func testEvaluate_blackMaterialAdvantage_isNegative() {
        var board = ChessBoard()
        board[Square(3, 0)] = nil  // remove white queen
        XCTAssertLessThan(engine.evaluate(board: board), 0)
    }

    // MARK: - bestMove

    func testBestMove_startingPosition_returnsNonNil() {
        let move = engine.bestMove(for: .white, on: ChessBoard(), depth: 1)
        XCTAssertNotNil(move)
    }

    func testBestMove_noLegalMoves_returnsNil() {
        // Fool's mate — white is checkmated, no legal moves
        let fen = "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        XCTAssertNil(engine.bestMove(for: .white, on: board, depth: 1))
    }

    func testBestMove_capturesHangingPiece() {
        // White queen d4, black bishop e5 undefended — best move should capture on e5
        let fen = "7k/8/8/4b3/3Q4/8/8/K7 w - - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let move = engine.bestMove(for: .white, on: board, depth: 1)
        XCTAssertEqual(move?.to, Square(4, 4))  // Qxe5
    }

    // MARK: - En passant

    func testEnPassant_squareSetAfterDoublePush() {
        let board = ChessBoard()
        let pawn = board[Square(4, 1)]!
        let move = ChessMove(from: Square(4, 1), to: Square(4, 3), piece: pawn)
        let newBoard = engine.applyMove(move, to: board)
        XCTAssertEqual(newBoard.enPassantSquare, Square(4, 2))  // e3
    }

    func testEnPassant_exposingKingToCheck_isIllegal() {
        // White king a5, white pawn b5, black pawn c5 (just double-pushed, EP = c6),
        // black rook g5.  Taking bxc6 ep removes BOTH pawns from rank 5, uncovering
        // the black rook's attack on the white king — the EP capture is illegal.
        let fen = "7k/8/8/KPp3r1/8/8/8/8 w - c6 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let b5 = Square(1, 4)
        let pawn = board[b5]!
        let moves = engine.legalMoves(for: pawn, at: b5, on: board)
        XCTAssertFalse(moves.contains { $0.isEnPassant })        // EP filtered (discovered check)
        XCTAssertTrue(moves.contains { $0.to == Square(1, 5) })  // b6 still legal
    }

    func testEnPassant_notAvailableWithoutEpSquare() {
        // Same pawn layout as capturedPawnRemovedFromBoard but the EP square is not
        // set (-) — en passant opportunity has expired, capture must not appear.
        let fen = "7k/8/8/3Pp3/8/8/8/K7 w - - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }
        let d5 = Square(3, 4)
        let pawn = board[d5]!
        let moves = engine.legalMoves(for: pawn, at: d5, on: board)
        XCTAssertFalse(moves.contains { $0.isEnPassant })  // no EP square → no EP capture
        XCTAssertEqual(moves.count, 1)                     // only d6 is available
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
