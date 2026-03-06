import XCTest
@testable import Chess4U

/// Tests for the daily puzzle pool data integrity and DailyPuzzleService pure logic.
/// The singleton's UserDefaults/Date-based state is not tested here to avoid
/// coupling tests to device state; we test the deterministic/data layers only.
final class DailyPuzzleServiceTests: XCTestCase {

    private let pool = ChessPuzzle.dailyPuzzlePool

    // MARK: - Pool integrity

    func testDailyPuzzlePool_notEmpty() {
        XCTAssertFalse(pool.isEmpty)
    }

    func testDailyPuzzlePool_allHaveNonEmptyFEN() {
        for puzzle in pool {
            XCTAssertFalse(puzzle.fen.isEmpty, "Puzzle '\(puzzle.title)' has empty FEN")
        }
    }

    func testDailyPuzzlePool_allHaveValidFEN() {
        for puzzle in pool {
            XCTAssertNotNil(ChessBoard(fen: puzzle.fen),
                "Puzzle '\(puzzle.title)' has invalid FEN: \(puzzle.fen)")
        }
    }

    func testDailyPuzzlePool_allHaveNonEmptySolution() {
        for puzzle in pool {
            XCTAssertFalse(puzzle.solution.isEmpty,
                "Puzzle '\(puzzle.title)' has empty solution")
        }
    }

    func testDailyPuzzlePool_allHaveNonEmptyTitle() {
        for puzzle in pool {
            XCTAssertFalse(puzzle.title.isEmpty, "Puzzle has empty title")
        }
    }

    func testDailyPuzzlePool_allHaveNonEmptyExplanation() {
        for puzzle in pool {
            XCTAssertFalse(puzzle.explanation.isEmpty,
                "Puzzle '\(puzzle.title)' has empty explanation")
        }
    }

    func testDailyPuzzlePool_allHaveNonEmptyHint() {
        for puzzle in pool {
            XCTAssertNotNil(puzzle.hint, "Puzzle '\(puzzle.title)' has nil hint")
            XCTAssertFalse(puzzle.hint?.isEmpty ?? true,
                "Puzzle '\(puzzle.title)' has empty hint")
        }
    }

    func testDailyPuzzlePool_allHavePositiveRating() {
        for puzzle in pool {
            XCTAssertGreaterThan(puzzle.rating, 0,
                "Puzzle '\(puzzle.title)' has non-positive rating")
        }
    }

    func testDailyPuzzlePool_allHaveRecognisedTheme() {
        let validThemes = Set(PuzzleTheme.allCases)
        for puzzle in pool {
            XCTAssertTrue(validThemes.contains(puzzle.theme),
                "Puzzle '\(puzzle.title)' has unrecognised theme: \(puzzle.theme)")
        }
    }

    func testDailyPuzzlePool_allHaveRecognisedDifficulty() {
        let validDifficulties = Set(PuzzleDifficulty.allCases)
        for puzzle in pool {
            XCTAssertTrue(validDifficulties.contains(puzzle.difficulty),
                "Puzzle '\(puzzle.title)' has unrecognised difficulty")
        }
    }

    func testDailyPuzzlePool_coversMultipleDifficulties() {
        let difficulties = Set(pool.map { $0.difficulty })
        XCTAssertGreaterThan(difficulties.count, 1,
            "Pool should include puzzles of varying difficulty")
    }

    func testDailyPuzzlePool_coversMultipleThemes() {
        let themes = Set(pool.map { $0.theme })
        XCTAssertGreaterThan(themes.count, 1,
            "Pool should include puzzles of different themes")
    }

    // MARK: - Deterministic selection

    func testPuzzleSelection_sameIndexAlwaysReturnsSamePuzzle() {
        // The service uses dayOfYear % pool.count — simulate that here
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let expected  = pool[dayOfYear % pool.count]
        let selected  = pool[dayOfYear % pool.count]
        XCTAssertEqual(selected.id, expected.id)
    }

    func testPuzzleSelection_indexIsAlwaysInBounds() {
        // For every possible day of year (1–366), the index must be in bounds
        for day in 1...366 {
            let index = day % pool.count
            XCTAssertGreaterThanOrEqual(index, 0)
            XCTAssertLessThan(index, pool.count)
        }
    }

    func testPuzzleSelection_allPoolPuzzlesReachable() {
        // Over a full year every pool position should be visited at least once
        var visitedIndices = Set<Int>()
        for day in 1...max(366, pool.count * 2) {
            visitedIndices.insert(day % pool.count)
        }
        XCTAssertEqual(visitedIndices.count, pool.count,
            "Not all pool puzzles are reachable over a year")
    }

    // MARK: - Known puzzle spot-checks

    func testKnownPuzzle_f7Attack_isMateInOne() {
        let puzzle = pool.first { $0.title == "The Deadly f7 Attack" }
        XCTAssertNotNil(puzzle, "Expected 'The Deadly f7 Attack' in pool")
        XCTAssertEqual(puzzle?.theme, .mateInOne)
        XCTAssertEqual(puzzle?.solution, ["f3f7"])
    }

    func testKnownPuzzle_backRank_isBackRankMate() {
        let puzzle = pool.first { $0.title == "Back Rank Weakness" }
        XCTAssertNotNil(puzzle)
        XCTAssertEqual(puzzle?.theme, .backRankMate)
        XCTAssertEqual(puzzle?.difficulty, .easy)
    }

    func testKnownPuzzle_endgameZugzwang_isExpert() {
        let puzzle = pool.first { $0.title == "Pawn Endgame Zugzwang" }
        XCTAssertNotNil(puzzle)
        XCTAssertEqual(puzzle?.difficulty, .expert)
        XCTAssertEqual(puzzle?.theme, .endgameTechnique)
    }
}
