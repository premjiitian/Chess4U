import XCTest
import SwiftUI
@testable import Chess4U

@MainActor
final class GameAnalysisViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeMoveAnalysis(quality: MoveQuality) -> MoveAnalysis {
        let piece = ChessPiece(type: .pawn, color: .white)
        let move  = ChessMove(from: Square(4, 1), to: Square(4, 3), piece: piece)
        return MoveAnalysis(moveNumber: 1, move: move,
                            quality: quality,
                            explanation: "test", evaluation: 0.0)
    }

    /// Returns a ChessGame with `count` moves played (alternating e4/e5 knight shuffles).
    private func makeGame(moves count: Int) -> ChessGame {
        // Use legal moves from the engine so makeMove succeeds
        let game = ChessGame()
        let engine = ChessEngineService.shared

        // Knight shuffle: Nf3, Nf6, Ng1, Ng8 repeated — all valid moves
        let whiteMoves: [(Int, Int, Int, Int)] = [(6,0,5,2),(6,0,5,2),(5,2,6,0),(5,2,6,0)]
        let blackMoves: [(Int, Int, Int, Int)] = [(6,7,5,5),(6,7,5,5),(5,5,6,7),(5,5,6,7)]
        var played = 0
        var whiteIdx = 0, blackIdx = 0

        while played < count {
            let board = game.board
            if board.activeColor == .white && whiteIdx < whiteMoves.count {
                let t = whiteMoves[whiteIdx % whiteMoves.count]
                if let p = board[Square(t.0, t.1)] {
                    let legal = engine.legalMoves(for: p, at: Square(t.0, t.1), on: board)
                    if let m = legal.first(where: { $0.to == Square(t.2, t.3) }) {
                        game.makeMove(m); played += 1; whiteIdx += 1; continue
                    }
                }
            } else if board.activeColor == .black && blackIdx < blackMoves.count {
                let t = blackMoves[blackIdx % blackMoves.count]
                if let p = board[Square(t.0, t.1)] {
                    let legal = engine.legalMoves(for: p, at: Square(t.0, t.1), on: board)
                    if let m = legal.first(where: { $0.to == Square(t.2, t.3) }) {
                        game.makeMove(m); played += 1; blackIdx += 1; continue
                    }
                }
            }
            break   // safety exit
        }
        return game
    }

    // MARK: - Initial state

    func testInit_currentMoveIndex_isZero() {
        let vm = GameAnalysisViewModel()
        XCTAssertEqual(vm.currentMoveIndex, 0)
    }

    func testInit_isAnalyzing_isFalse() {
        let vm = GameAnalysisViewModel()
        XCTAssertFalse(vm.isAnalyzing)
    }

    func testInit_evaluationGraphData_isEmpty() {
        let vm = GameAnalysisViewModel()
        XCTAssertTrue(vm.evaluationGraphData.isEmpty)
    }

    func testInit_moveQualityColor_gray_whenNoMistakeSelected() {
        let vm = GameAnalysisViewModel()
        XCTAssertEqual(vm.moveQualityColor, Color.gray)
    }

    // MARK: - moveQualityColor

    func testMoveQualityColor_blunder_isRed() {
        let vm = GameAnalysisViewModel()
        vm.selectedMistake = makeMoveAnalysis(quality: .blunder)
        XCTAssertEqual(vm.moveQualityColor, Color.red)
    }

    func testMoveQualityColor_mistake_isOrange() {
        let vm = GameAnalysisViewModel()
        vm.selectedMistake = makeMoveAnalysis(quality: .mistake)
        XCTAssertEqual(vm.moveQualityColor, Color.orange)
    }

    func testMoveQualityColor_inaccuracy_isYellow() {
        let vm = GameAnalysisViewModel()
        vm.selectedMistake = makeMoveAnalysis(quality: .inaccuracy)
        XCTAssertEqual(vm.moveQualityColor, Color.yellow)
    }

    func testMoveQualityColor_acceptable_isBlue() {
        let vm = GameAnalysisViewModel()
        vm.selectedMistake = makeMoveAnalysis(quality: .acceptable)
        XCTAssertEqual(vm.moveQualityColor, Color.blue)
    }

    func testMoveQualityColor_best_isGreen() {
        let vm = GameAnalysisViewModel()
        vm.selectedMistake = makeMoveAnalysis(quality: .best)
        XCTAssertEqual(vm.moveQualityColor, Color.green)
    }

    func testMoveQualityColor_good_isGreen() {
        let vm = GameAnalysisViewModel()
        vm.selectedMistake = makeMoveAnalysis(quality: .good)
        XCTAssertEqual(vm.moveQualityColor, Color.green)
    }

    // MARK: - goToMove / navigation

    func testGoToMove_clampsBelowZero() {
        let vm = GameAnalysisViewModel()
        vm.game = makeGame(moves: 2)
        vm.goToMove(-5)
        XCTAssertEqual(vm.currentMoveIndex, 0)
    }

    func testGoToMove_clampsAboveMoveCount() {
        let vm = GameAnalysisViewModel()
        let game = makeGame(moves: 2)
        vm.game = game
        vm.goToMove(100)
        XCTAssertEqual(vm.currentMoveIndex, game.moves.count)
    }

    func testGoToMove_setsValidIndex() {
        let vm = GameAnalysisViewModel()
        let game = makeGame(moves: 2)
        vm.game = game
        vm.goToMove(1)
        XCTAssertEqual(vm.currentMoveIndex, 1)
    }

    func testNextMove_incrementsIndex() {
        let vm = GameAnalysisViewModel()
        let game = makeGame(moves: 2)
        vm.game = game
        vm.currentMoveIndex = 0
        vm.nextMove()
        XCTAssertEqual(vm.currentMoveIndex, 1)
    }

    func testPreviousMove_decrementsIndex() {
        let vm = GameAnalysisViewModel()
        let game = makeGame(moves: 2)
        vm.game = game
        vm.currentMoveIndex = 2
        vm.previousMove()
        XCTAssertEqual(vm.currentMoveIndex, 1)
    }

    func testFirstMove_setsZero() {
        let vm = GameAnalysisViewModel()
        let game = makeGame(moves: 2)
        vm.game = game
        vm.currentMoveIndex = 2
        vm.firstMove()
        XCTAssertEqual(vm.currentMoveIndex, 0)
    }

    func testLastMove_setsToMoveCount() {
        let vm = GameAnalysisViewModel()
        let game = makeGame(moves: 2)
        vm.game = game
        vm.currentMoveIndex = 0
        vm.lastMove()
        XCTAssertEqual(vm.currentMoveIndex, game.moves.count)
    }
}
