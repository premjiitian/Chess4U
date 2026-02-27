import XCTest
@testable import Chess4U

final class AICoachServiceTests: XCTestCase {

    private let coach = AICoachService.shared

    private func makeProfile(elo: Int = 1200) -> PlayerProfile {
        PlayerProfile(
            name: "Test", elo: elo,
            preferredTimeControl: .rapid, playerType: .casual,
            mainOpeningsWhite: [], mainDefensesBlack: [],
            ratingTrend: .stable, weaknesses: []
        )
    }

    private func makePuzzle(
        theme: PuzzleTheme = .fork,
        hint: String? = nil,
        solution: [String] = ["e2e4"]
    ) -> ChessPuzzle {
        ChessPuzzle(
            fen: ChessBoard.startingFEN,
            solution: solution,
            theme: theme,
            difficulty: .medium,
            playerToMove: .white,
            rating: 1400,
            title: "Test Puzzle",
            explanation: "Test explanation",
            hint: hint
        )
    }

    // MARK: - generateHint

    func testGenerateHint_none_refusesHint() {
        let result = coach.generateHint(for: makePuzzle(), level: .none, board: ChessBoard())
        XCTAssertTrue(result.lowercased().contains("no hint"))
    }

    func testGenerateHint_minimal_containsThemeName() {
        let puzzle = makePuzzle(theme: .fork)
        let result = coach.generateHint(for: puzzle, level: .minimal, board: ChessBoard())
        XCTAssertTrue(result.contains("Fork"), "Minimal hint should name the theme, got: \(result)")
    }

    func testGenerateHint_medium_withPuzzleHint_returnsThatHint() {
        let puzzle = makePuzzle(hint: "Look for the knight jump")
        let result = coach.generateHint(for: puzzle, level: .medium, board: ChessBoard())
        XCTAssertTrue(result.contains("Look for the knight jump"))
    }

    func testGenerateHint_medium_withoutHint_returnsDefault() {
        let puzzle = makePuzzle(hint: nil)
        let result = coach.generateHint(for: puzzle, level: .medium, board: ChessBoard())
        XCTAssertTrue(result.contains("forcing moves"))
    }

    func testGenerateHint_full_withValidSolution_mentionsFile() {
        // Solution "e2e4" → Square(algebraic: "e2") → file 4 → char "e"
        let puzzle = makePuzzle(hint: nil, solution: ["e2e4"])
        let result = coach.generateHint(for: puzzle, level: .full, board: ChessBoard())
        XCTAssertTrue(result.contains("e file"), "Full hint should mention 'e file', got: \(result)")
    }

    // MARK: - generateCommentary

    func testGenerateCommentary_checkmate_mentionsCheckmate() {
        // Fool's Mate — white is in checkmate (black wins)
        let fen = "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parse failed"); return }
        let result = coach.generateCommentary(for: board, profile: makeProfile())
        XCTAssertTrue(result.lowercased().contains("checkmate"),
            "Commentary for checkmate should say 'checkmate', got: \(result)")
    }

    func testGenerateCommentary_stalemate_mentionsStalemate() {
        // Black to move, black king on a8 has no legal moves, not in check
        let fen = "k7/2Q5/1K6/8/8/8/8/8 b - - 0 1"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parse failed"); return }
        let result = coach.generateCommentary(for: board, profile: makeProfile())
        XCTAssertTrue(result.contains("Stalemate"), "Got: \(result)")
    }

    func testGenerateCommentary_check_mentionsCheck() {
        // After 1.e4 f5 2.Qh5+ — black is in check (not checkmate, can escape to d7)
        let fen = "rnbqkbnr/ppppp1pp/8/5p1Q/4P3/8/PPPP1PPP/RNB1KBNR b KQkq - 1 2"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN parse failed"); return }
        let result = coach.generateCommentary(for: board, profile: makeProfile())
        XCTAssertTrue(result.lowercased().contains("check"),
            "Commentary for check should mention 'check', got: \(result)")
    }

    func testGenerateCommentary_equalPosition_mentionsEqual() {
        let result = coach.generateCommentary(for: ChessBoard(), profile: makeProfile())
        XCTAssertTrue(result.lowercased().contains("equal"), "Got: \(result)")
    }

    func testGenerateCommentary_isNonEmpty() {
        XCTAssertFalse(coach.generateCommentary(for: ChessBoard(), profile: makeProfile()).isEmpty)
    }

    // MARK: - generateAudioScript

    func testGenerateAudioScript_containsTitle() {
        let lesson = ConceptLesson(
            title: "Tactical Vision",
            concept: "Fork",
            explanation: "A fork attacks two pieces at once.",
            example: "Knight on c7 attacks king and rook.",
            keyIdea: "Attack two targets simultaneously.",
            commonMistake: "Missing fork setups.",
            howStrongPlayersUseIt: "They constantly look for fork opportunities.",
            type: .tactics, playerBand: .bandA
        )
        let script = coach.generateAudioScript(for: lesson)
        XCTAssertTrue(script.contains("Tactical Vision"), "Script should contain lesson title")
        XCTAssertTrue(script.contains("A fork attacks two pieces at once."), "Script should contain explanation")
        XCTAssertTrue(script.contains("Attack two targets simultaneously."), "Script should contain key idea")
    }

    // MARK: - variationComment

    func testVariationComment_incorrect_mentionsPlayedMove() {
        let move = ChessMove(
            from: Square(4, 1), to: Square(4, 2),
            piece: ChessPiece(type: .pawn, color: .white),
            notation: "e3"
        )
        let result = coach.variationComment(move: move, expectedMove: "e4", isCorrect: false)
        XCTAssertTrue(result.contains("e3"), "Should mention played move notation, got: \(result)")
        XCTAssertTrue(result.lowercased().contains("not quite"))
    }

    func testVariationComment_correct_isNonEmptyAndPositive() {
        let move = ChessMove(
            from: Square(4, 1), to: Square(4, 3),
            piece: ChessPiece(type: .pawn, color: .white),
            notation: "e4"
        )
        let result = coach.variationComment(move: move, expectedMove: "e4", isCorrect: true)
        XCTAssertFalse(result.isEmpty)
        XCTAssertFalse(result.lowercased().contains("not quite"),
            "Correct move commentary shouldn't say 'not quite'")
    }
}
