import XCTest
@testable import Chess4U

@MainActor
final class TrainingViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeProfile(elo: Int = 1200) -> PlayerProfile {
        PlayerProfile(
            name: "Tester", elo: elo,
            preferredTimeControl: .rapid, playerType: .casual,
            mainOpeningsWhite: [], mainDefensesBlack: [],
            ratingTrend: .stable, weaknesses: []
        )
    }

    private func makeSession(warmup: Int = 2, main: Int = 3, index: Int = 0) -> TrainingSession {
        let puzzles = Array(ChessPuzzle.puzzleDatabase.prefix(warmup + main))
        var s = TrainingSession(type: .tactics, playerBand: .bandB, startDate: Date())
        s.warmupPuzzles = Array(puzzles.prefix(warmup))
        s.mainPuzzles   = Array(puzzles.dropFirst(warmup).prefix(main))
        s.currentPuzzleIndex = index
        return s
    }

    private func makePuzzle() -> ChessPuzzle {
        ChessPuzzle.puzzleDatabase.first!
    }

    // MARK: - Initialisation

    func testInit_defaultValues() {
        let vm = TrainingViewModel()
        XCTAssertNil(vm.session)
        XCTAssertNil(vm.currentPuzzle)
        XCTAssertEqual(vm.puzzleState, .idle)
        XCTAssertTrue(vm.solutionMoves.isEmpty)
        XCTAssertEqual(vm.currentSolutionIndex, 0)
        XCTAssertTrue(vm.hintText.isEmpty)
        XCTAssertTrue(vm.coachComment.isEmpty)
        XCTAssertFalse(vm.showLesson)
        XCTAssertFalse(vm.showBlunderCheck)
        XCTAssertTrue(vm.blunderCheckQuestions.isEmpty)
        XCTAssertEqual(vm.sessionScore, 0)
        XCTAssertFalse(vm.isSessionComplete)
    }

    func testInit_withProfile_storesProfile() {
        let profile = makeProfile()
        let vm = TrainingViewModel(profile: profile)
        XCTAssertEqual(vm.profile?.name, "Tester")
    }

    // MARK: - currentPuzzleProgress

    func testCurrentPuzzleProgress_nilSession_returnsZero() {
        let vm = TrainingViewModel()
        XCTAssertEqual(vm.currentPuzzleProgress, 0.0, accuracy: 1e-9)
    }

    func testCurrentPuzzleProgress_emptyPuzzleLists_returnsZero() {
        let vm = TrainingViewModel()
        var s = TrainingSession(type: .tactics, playerBand: .bandA, startDate: Date())
        s.currentPuzzleIndex = 0
        vm.session = s
        XCTAssertEqual(vm.currentPuzzleProgress, 0.0, accuracy: 1e-9)
    }

    func testCurrentPuzzleProgress_withSession_correctFraction() {
        let vm = TrainingViewModel()
        // 2 warmup + 3 main = 5 total, index = 1 → 1/5 = 0.2
        vm.session = makeSession(warmup: 2, main: 3, index: 1)
        XCTAssertEqual(vm.currentPuzzleProgress, 0.2, accuracy: 1e-9)
    }

    func testCurrentPuzzleProgress_atEnd_returnsOne() {
        let vm = TrainingViewModel()
        vm.session = makeSession(warmup: 2, main: 3, index: 5)
        XCTAssertEqual(vm.currentPuzzleProgress, 1.0, accuracy: 1e-9)
    }

    // MARK: - PuzzleState enum

    func testPuzzleState_idle_isDistinctFromOtherCases() {
        XCTAssertNotEqual(PuzzleState.idle, .waitingForMove)
        XCTAssertNotEqual(PuzzleState.idle, .correct)
        XCTAssertNotEqual(PuzzleState.idle, .incorrect)
        XCTAssertNotEqual(PuzzleState.idle, .solved)
        XCTAssertNotEqual(PuzzleState.idle, .showingSolution)
    }

    // MARK: - startSession

    func testStartSession_nilProfile_doesNothing() {
        let vm = TrainingViewModel()   // no profile
        vm.startSession(type: .tactics)
        XCTAssertNil(vm.session)
    }

    func testStartSession_withProfile_setsSession() {
        let vm = TrainingViewModel(profile: makeProfile())
        vm.startSession(type: .tactics)
        XCTAssertNotNil(vm.session)
    }

    // MARK: - loadPuzzle

    func testLoadPuzzle_setsSolutionMoves() {
        let vm = TrainingViewModel(profile: makeProfile())
        let puzzle = makePuzzle()
        vm.loadPuzzle(puzzle)
        XCTAssertEqual(vm.solutionMoves, puzzle.solution)
    }

    func testLoadPuzzle_resetsSolutionIndex() {
        let vm = TrainingViewModel(profile: makeProfile())
        vm.currentSolutionIndex = 5   // pre-set
        vm.loadPuzzle(makePuzzle())
        XCTAssertEqual(vm.currentSolutionIndex, 0)
    }

    func testLoadPuzzle_setsPuzzleState_waitingForMove() {
        let vm = TrainingViewModel(profile: makeProfile())
        vm.loadPuzzle(makePuzzle())
        XCTAssertEqual(vm.puzzleState, .waitingForMove)
    }

    func testLoadPuzzle_setsCurrentPuzzle() {
        let vm = TrainingViewModel(profile: makeProfile())
        let puzzle = makePuzzle()
        vm.loadPuzzle(puzzle)
        XCTAssertEqual(vm.currentPuzzle?.id, puzzle.id)
    }

    // MARK: - handlePlayerMove

    func testHandlePlayerMove_nilPuzzle_doesNothing() {
        let vm = TrainingViewModel(profile: makeProfile())
        // no puzzle loaded — should not crash
        let piece = ChessPiece(type: .pawn, color: .white)
        let move  = ChessMove(from: Square(4, 1), to: Square(4, 3), piece: piece)
        vm.handlePlayerMove(move)   // must not crash
        XCTAssertNil(vm.currentPuzzle)
    }

    func testHandlePlayerMove_wrongState_doesNothing() {
        let vm = TrainingViewModel(profile: makeProfile())
        vm.loadPuzzle(makePuzzle())
        vm.puzzleState = .solved   // not .waitingForMove
        let piece = ChessPiece(type: .pawn, color: .white)
        let move  = ChessMove(from: Square(4, 1), to: Square(4, 3), piece: piece)
        vm.handlePlayerMove(move)   // must not crash or alter state
        XCTAssertEqual(vm.puzzleState, .solved)   // unchanged
    }
}
