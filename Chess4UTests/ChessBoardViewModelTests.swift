import XCTest
@testable import Chess4U

@MainActor
final class ChessBoardViewModelTests: XCTestCase {

    // MARK: - Initialisation

    func testInit_defaultState() {
        let vm = ChessBoardViewModel()
        XCTAssertNil(vm.selectedSquare)
        XCTAssertTrue(vm.legalMoveSquares.isEmpty)
        XCTAssertNil(vm.lastMove)
        XCTAssertNil(vm.promotionPending)
        XCTAssertFalse(vm.isFlipped)
        XCTAssertTrue(vm.highlightedSquares.isEmpty)
        XCTAssertTrue(vm.arrows.isEmpty)
        XCTAssertNil(vm.coachInsight)
        XCTAssertNil(vm.animatingMove)
        XCTAssertFalse(vm.isAIThinking)
        XCTAssertFalse(vm.showHints)
    }

    func testInit_fen_loadsPosition() {
        // Rook + King endgame — white rook on a1 (file 0, rank 0)
        let fen = "4k3/8/8/8/8/8/8/R3K3 w Q - 0 1"
        let vm = ChessBoardViewModel(fen: fen)
        let piece = vm.game.board[Square(0, 0)]
        XCTAssertNotNil(piece)
        XCTAssertEqual(piece?.type, .rook)
        XCTAssertEqual(piece?.color, .white)
    }

    func testInit_fen_statusMessageSet() {
        let vm = ChessBoardViewModel(fen: "4k3/8/8/8/8/8/8/4K3 w - - 0 1")
        XCTAssertFalse(vm.statusMessage.isEmpty)
    }

    // MARK: - statusMessage

    func testStatusMessage_initial_whiteToMove() {
        let vm = ChessBoardViewModel()
        XCTAssertEqual(vm.statusMessage, "White to move")
    }

    // MARK: - squareColor

    func testSquareColor_lightAndDarkAlternate() {
        let vm = ChessBoardViewModel()
        // a1 = (0,0): file+rank=0 (even) → dark square
        // b1 = (1,0): file+rank=1 (odd)  → light square
        let dark  = vm.squareColor(file: 0, rank: 0)
        let light = vm.squareColor(file: 1, rank: 0)
        XCTAssertNotEqual(dark, light, "Adjacent squares must have different colours")
    }

    func testSquareColor_sameParitySquaresMatch() {
        let vm = ChessBoardViewModel()
        // (0,0) and (2,0) are both dark (file+rank even)
        XCTAssertEqual(vm.squareColor(file: 0, rank: 0), vm.squareColor(file: 2, rank: 0))
        // (1,0) and (3,0) are both light (file+rank odd)
        XCTAssertEqual(vm.squareColor(file: 1, rank: 0), vm.squareColor(file: 3, rank: 0))
    }

    func testSquareColor_differsByTheme() {
        var settingsClassic = AppSettings(); settingsClassic.boardTheme = .classic
        var settingsWood    = AppSettings(); settingsWood.boardTheme    = .wood
        let vmC = ChessBoardViewModel(settings: settingsClassic)
        let vmW = ChessBoardViewModel(settings: settingsWood)
        // Light square (b1 = file 1, rank 0)
        XCTAssertNotEqual(vmC.squareColor(file: 1, rank: 0), vmW.squareColor(file: 1, rank: 0))
    }

    // MARK: - isSelected

    func testIsSelected_falseByDefault() {
        let vm = ChessBoardViewModel()
        XCTAssertFalse(vm.isSelected(Square(4, 1)))
    }

    func testIsSelected_trueAfterSelectSquare() {
        let vm = ChessBoardViewModel()
        vm.selectSquare(Square(4, 1))   // e2 pawn
        XCTAssertTrue(vm.isSelected(Square(4, 1)))
    }

    // MARK: - isLegalMove

    func testIsLegalMove_falseByDefault() {
        let vm = ChessBoardViewModel()
        XCTAssertFalse(vm.isLegalMove(Square(4, 2)))
    }

    func testIsLegalMove_trueAfterSelectPawn() {
        let vm = ChessBoardViewModel()
        vm.selectSquare(Square(4, 1))   // e2 pawn selected
        XCTAssertTrue(vm.isLegalMove(Square(4, 2)))   // e3
        XCTAssertTrue(vm.isLegalMove(Square(4, 3)))   // e4
    }

    // MARK: - isLastMove

    func testIsLastMove_falseByDefault() {
        let vm = ChessBoardViewModel()
        XCTAssertFalse(vm.isLastMove(Square(0, 0)))
    }

    func testIsLastMove_trueForBothFromAndTo() {
        let vm = ChessBoardViewModel()
        let from = Square(4, 1)
        let to   = Square(4, 3)
        vm.lastMove = ChessMove(from: from, to: to, piece: ChessPiece(type: .pawn, color: .white))
        XCTAssertTrue(vm.isLastMove(from))
        XCTAssertTrue(vm.isLastMove(to))
        XCTAssertFalse(vm.isLastMove(Square(0, 0)))
    }

    // MARK: - goToStart

    func testGoToStart_resetsToInitialPosition() {
        let vm = ChessBoardViewModel()
        // Make e4
        vm.selectSquare(Square(4, 1))
        vm.selectSquare(Square(4, 3))
        XCTAssertFalse(vm.game.moves.isEmpty, "Precondition: move was made")
        vm.goToStart()
        XCTAssertTrue(vm.game.moves.isEmpty)
        XCTAssertNil(vm.selectedSquare)
        XCTAssertNil(vm.lastMove)
        // e2 pawn back in place
        XCTAssertNotNil(vm.game.board[Square(4, 1)])
    }

    // MARK: - undoLastMove

    func testUndoLastMove_noMoves_doesNothing() {
        let vm = ChessBoardViewModel()
        let initialFen = vm.game.board.fen
        vm.undoLastMove()
        XCTAssertEqual(vm.game.board.fen, initialFen)
        XCTAssertNil(vm.lastMove)
    }

    func testUndoLastMove_afterOneMove_restoresPosition() {
        let vm = ChessBoardViewModel()
        let initialFen = vm.game.board.fen
        vm.selectSquare(Square(4, 1))   // select e2 pawn
        vm.selectSquare(Square(4, 3))   // play e4
        XCTAssertFalse(vm.game.moves.isEmpty, "Precondition: e4 was played")
        vm.undoLastMove()
        XCTAssertTrue(vm.game.moves.isEmpty)
        XCTAssertNil(vm.lastMove)
        XCTAssertEqual(vm.game.board.fen, initialFen)
    }

    // MARK: - selectSquare

    func testSelectSquare_deselectsWhenEmptyTargetChosen() {
        let vm = ChessBoardViewModel()
        vm.selectSquare(Square(4, 1))   // select e2 pawn
        XCTAssertTrue(vm.isSelected(Square(4, 1)))
        // e5 is empty at start and not a legal move for the pawn from e2
        vm.selectSquare(Square(4, 4))
        XCTAssertNil(vm.selectedSquare)
        XCTAssertTrue(vm.legalMoveSquares.isEmpty)
    }

    func testSelectSquare_whenPromotionPending_doesNothing() {
        let vm = ChessBoardViewModel()
        vm.promotionPending = Square(4, 7)   // simulate awaiting promotion
        let prevSelected = vm.selectedSquare
        vm.selectSquare(Square(0, 0))
        XCTAssertEqual(vm.selectedSquare, prevSelected)   // unchanged
    }

    func testSelectSquare_reSelectsDifferentPiece() {
        let vm = ChessBoardViewModel()
        vm.selectSquare(Square(4, 1))   // e2 pawn
        XCTAssertTrue(vm.isSelected(Square(4, 1)))
        vm.selectSquare(Square(3, 1))   // d2 pawn — different own piece
        XCTAssertTrue(vm.isSelected(Square(3, 1)))
        XCTAssertFalse(vm.isSelected(Square(4, 1)))
    }
}
