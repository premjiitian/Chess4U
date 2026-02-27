import XCTest
@testable import Chess4U

final class ChessGameTests: XCTestCase {

    // MARK: - Initialisation

    func testInit_defaultPlayers() {
        let game = ChessGame()
        XCTAssertEqual(game.whitePlayer, "Player")
        XCTAssertEqual(game.blackPlayer, "AI Coach")
    }

    func testInit_customPlayers() {
        let game = ChessGame(whitePlayer: "Alice", blackPlayer: "Bob")
        XCTAssertEqual(game.whitePlayer, "Alice")
        XCTAssertEqual(game.blackPlayer, "Bob")
    }

    func testInit_statusIsActive() {
        XCTAssertEqual(ChessGame().status, .active)
    }

    func testInit_movesEmpty() {
        XCTAssertTrue(ChessGame().moves.isEmpty)
    }

    func testInit_isWhiteTurn() {
        XCTAssertTrue(ChessGame().isWhiteTurn)
    }

    func testInit_currentMoveIsZero() {
        XCTAssertEqual(ChessGame().currentMove, 0)
    }

    func testInit_positionHistoryContainsStartingKey() {
        let game = ChessGame()
        // positionHistory holds the 4-field position key, not the full FEN
        XCTAssertEqual(game.positionHistory.count, 1)
        let key = game.positionHistory[0]
        XCTAssertTrue(key.hasPrefix("rnbqkbnr/pppppppp"))
        XCTAssertFalse(key.contains(" 0 1"), "full FEN (with move counters) should not be stored")
    }

    // MARK: - makeMove

    func testMakeMove_incrementsCurrentMove() {
        let game  = ChessGame()
        let pawn  = game.board[Square(4, 1)]!
        let move  = ChessMove(from: Square(4, 1), to: Square(4, 3), piece: pawn)
        game.makeMove(move)
        XCTAssertEqual(game.currentMove, 1)
    }

    func testMakeMove_appendsToMoves() {
        let game = ChessGame()
        let pawn = game.board[Square(4, 1)]!
        let move = ChessMove(from: Square(4, 1), to: Square(4, 3), piece: pawn)
        game.makeMove(move)
        XCTAssertEqual(game.moves.count, 1)
    }

    func testMakeMove_pawnAdvancesOnBoard() {
        let game = ChessGame()
        let pawn = game.board[Square(4, 1)]!
        game.makeMove(ChessMove(from: Square(4, 1), to: Square(4, 3), piece: pawn))
        XCTAssertNil(game.board[Square(4, 1)])           // e2 now empty
        XCTAssertEqual(game.board[Square(4, 3)]?.type, .pawn)  // e4 occupied
    }

    func testMakeMove_switchesTurn() {
        let game = ChessGame()
        let pawn = game.board[Square(4, 1)]!
        game.makeMove(ChessMove(from: Square(4, 1), to: Square(4, 3), piece: pawn))
        XCTAssertFalse(game.isWhiteTurn)  // now black's turn
    }

    // MARK: - Status: check

    func testStatus_check_detectedAfterMove() {
        // 1.e4 f5 2.Qh5+ — black's f-pawn moves from f7 to f5, opening the h5-e8
        // diagonal. The white queen reaches h5 via d1-e2-f3-g4-h5 (e2 vacated by e4)
        // and gives check along h5-g6-f7(empty)-e8.  Black can escape to d7, so it
        // is .check, not .checkmate.
        let game = ChessGame()
        func mv(_ f1: Int, _ r1: Int, _ f2: Int, _ r2: Int) -> ChessMove {
            ChessMove(from: Square(f1, r1), to: Square(f2, r2), piece: game.board[Square(f1, r1)]!)
        }
        game.makeMove(mv(4,1,4,3))  // 1. e4  (opens d1-h5 diagonal)
        game.makeMove(mv(5,6,5,4))  // 1...f5 (vacates f7, opening h5-e8 diagonal)
        game.makeMove(mv(3,0,7,4))  // 2. Qh5+ (queen checks via g6-f7-e8)
        if case .check = game.status {
            // pass
        } else {
            XCTFail("Expected .check after Qh5+, got \(game.status)")
        }
    }

    // MARK: - Status: checkmate

    func testStatus_checkmate_foolsMate() {
        // Fool's mate: 1.f3 e5 2.g4 Qh4#
        let game = ChessGame()
        func mv(_ f1: Int, _ r1: Int, _ f2: Int, _ r2: Int) -> ChessMove {
            ChessMove(from: Square(f1, r1), to: Square(f2, r2), piece: game.board[Square(f1, r1)]!)
        }
        game.makeMove(mv(5,1,5,2))  // 1. f3
        game.makeMove(mv(4,6,4,4))  // 1...e5
        game.makeMove(mv(6,1,6,3))  // 2. g4
        game.makeMove(mv(3,7,7,3))  // 2...Qh4#
        if case .checkmate(let winner) = game.status {
            XCTAssertEqual(winner, .black)
        } else {
            XCTFail("Expected checkmate, got \(game.status)")
        }
        XCTAssertEqual(game.result, .blackWins)
    }

    // MARK: - Threefold repetition

    func testStatus_threefoldRepetition_detectedAfterThreeRepeats() {
        // Shuttle Ng1-Nf3-Ng1-Nf3-Ng1-Nf3 interleaved with Ng8-Nf6-Ng8-Nf6-Ng8
        // produces the same position (both knights home) three times.
        let game = ChessGame()
        func mv(_ f1: Int, _ r1: Int, _ f2: Int, _ r2: Int) -> ChessMove {
            ChessMove(from: Square(f1, r1), to: Square(f2, r2), piece: game.board[Square(f1, r1)]!)
        }
        // Cycle 1
        game.makeMove(mv(6,0,5,2))  // Nf3
        game.makeMove(mv(6,7,5,5))  // Nf6
        game.makeMove(mv(5,2,6,0))  // Ng1
        game.makeMove(mv(5,5,6,7))  // Ng8  ← starting position repeated (count = 2)
        // Cycle 2
        game.makeMove(mv(6,0,5,2))  // Nf3
        game.makeMove(mv(6,7,5,5))  // Nf6
        game.makeMove(mv(5,2,6,0))  // Ng1
        game.makeMove(mv(5,5,6,7))  // Ng8  ← repeated 3 times → draw
        if case .draw(let reason) = game.status {
            XCTAssertEqual(reason, .repetition)
        } else {
            XCTFail("Expected threefold-repetition draw, got \(game.status)")
        }
        XCTAssertEqual(game.result, .draw)
    }

    // MARK: - pgnHeader

    func testPgnHeader_containsPlayerNames() {
        let game = ChessGame(whitePlayer: "Alice", blackPlayer: "Bob")
        XCTAssertTrue(game.pgnHeader.contains("Alice"))
        XCTAssertTrue(game.pgnHeader.contains("Bob"))
    }

    func testPgnHeader_containsResult() {
        let game = ChessGame()
        XCTAssertTrue(game.pgnHeader.contains(game.result.rawValue))
    }
}
