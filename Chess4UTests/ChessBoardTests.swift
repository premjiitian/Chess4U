import XCTest
@testable import Chess4U

final class ChessBoardTests: XCTestCase {

    // MARK: - Initial board

    func testInitialBoard_32Pieces() {
        let board = ChessBoard()
        var count = 0
        for f in 0...7 { for r in 0...7 { if board.squares[f][r] != nil { count += 1 } } }
        XCTAssertEqual(count, 32)
    }

    func testInitialBoard_whiteToMove() {
        XCTAssertEqual(ChessBoard().activeColor, .white)
    }

    func testInitialBoard_allCastlingRights() {
        let rights = ChessBoard().castlingRights
        XCTAssertTrue(rights.whiteKingside)
        XCTAssertTrue(rights.whiteQueenside)
        XCTAssertTrue(rights.blackKingside)
        XCTAssertTrue(rights.blackQueenside)
    }

    func testInitialBoard_kingSquares() {
        let board = ChessBoard()
        XCTAssertEqual(board.kingSquare(for: .white), Square(4, 0))  // e1
        XCTAssertEqual(board.kingSquare(for: .black), Square(4, 7))  // e8
    }

    func testInitialBoard_materialBalance_zero() {
        XCTAssertEqual(ChessBoard().materialBalance, 0)
    }

    func testInitialBoard_16PiecesEachSide() {
        let board = ChessBoard()
        XCTAssertEqual(board.allSquares(for: .white).count, 16)
        XCTAssertEqual(board.allSquares(for: .black).count, 16)
    }

    // MARK: - FEN parsing

    func testFENParsing_startingPosition() {
        let board = ChessBoard(fen: ChessBoard.startingFEN)
        XCTAssertNotNil(board)
        XCTAssertEqual(board?.activeColor, .white)
    }

    func testFENParsing_afterE4C5() {
        // After 1.e4 c5
        let fen = "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parsing failed"); return }

        let e4 = board[Square(4, 3)]
        XCTAssertEqual(e4?.type, .pawn)
        XCTAssertEqual(e4?.color, .white)

        let c5 = board[Square(2, 4)]
        XCTAssertEqual(c5?.type, .pawn)
        XCTAssertEqual(c5?.color, .black)

        XCTAssertEqual(board.enPassantSquare, Square(2, 5))  // c6
        XCTAssertEqual(board.activeColor, .white)
        XCTAssertEqual(board.fullMoveNumber, 2)
    }

    func testFENParsing_invalidReturnsNil() {
        XCTAssertNil(ChessBoard(fen: "invalid"))
        XCTAssertNil(ChessBoard(fen: ""))
        XCTAssertNil(ChessBoard(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"))  // missing fields
    }

    // MARK: - FEN roundtrip

    func testFENRoundtrip_startingPosition() {
        let board = ChessBoard()
        XCTAssertEqual(board.fen, ChessBoard.startingFEN)
    }

    func testFENRoundtrip_midGame() {
        let original = "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2"
        guard let board = ChessBoard(fen: original) else { XCTFail("FEN parsing failed"); return }
        XCTAssertEqual(board.fen, original)
    }

    // MARK: - materialBalance

    func testMaterialBalance_removeWhiteQueen() {
        var board = ChessBoard()
        board[Square(3, 0)] = nil  // remove white queen from d1
        // queen value = 9, so white is down 9
        XCTAssertEqual(board.materialBalance, -9)
    }

    func testMaterialBalance_removeBlackRook() {
        var board = ChessBoard()
        board[Square(0, 7)] = nil  // remove black rook from a8
        // rook value = 5, so white is up 5
        XCTAssertEqual(board.materialBalance, 5)
    }

    // MARK: - CastlingRights FEN string

    func testCastlingRights_fullString() {
        let rights = CastlingRights(whiteKingside: true, whiteQueenside: true,
                                    blackKingside: true, blackQueenside: true)
        XCTAssertEqual(rights.fenString, "KQkq")
    }

    func testCastlingRights_noneEmpty() {
        let rights = CastlingRights(whiteKingside: false, whiteQueenside: false,
                                    blackKingside: false, blackQueenside: false)
        XCTAssertEqual(rights.fenString, "")
    }

    func testCastlingRights_kingsideOnly() {
        let rights = CastlingRights(whiteKingside: true, whiteQueenside: false,
                                    blackKingside: true, blackQueenside: false)
        XCTAssertEqual(rights.fenString, "Kk")
    }
}
