import XCTest
@testable import Chess4U

final class ChessPuzzleTests: XCTestCase {

    // MARK: - PuzzleDifficulty ELO ranges

    func testPuzzleDifficulty_eloRanges() {
        XCTAssertEqual(PuzzleDifficulty.beginner.eloRange, 800...1000)
        XCTAssertEqual(PuzzleDifficulty.easy.eloRange,     1000...1300)
        XCTAssertEqual(PuzzleDifficulty.medium.eloRange,   1300...1600)
        XCTAssertEqual(PuzzleDifficulty.hard.eloRange,     1600...1800)
        XCTAssertEqual(PuzzleDifficulty.expert.eloRange,   1800...2200)
    }

    // MARK: - warmupPuzzles(for:)

    func testWarmupPuzzles_returnsAtMostFive() {
        for band in PlayerBand.allCases {
            let puzzles = ChessPuzzle.warmupPuzzles(for: band)
            XCTAssertLessThanOrEqual(puzzles.count, 5,
                "Band \(band.rawValue) returned \(puzzles.count) puzzles, expected ≤ 5")
        }
    }

    func testWarmupPuzzles_solutionDepthMatchesBand() {
        for band in PlayerBand.allCases {
            let puzzles = ChessPuzzle.warmupPuzzles(for: band)
            for puzzle in puzzles {
                let depth = puzzle.solution.count - 1
                XCTAssertTrue(band.calculationDepth.contains(depth),
                    "Depth \(depth) not in \(band.calculationDepth) for \(band.rawValue)")
            }
        }
    }

    func testWarmupPuzzles_bandA_eloLowerBound_atLeast800() {
        for puzzle in ChessPuzzle.warmupPuzzles(for: .bandA) {
            XCTAssertGreaterThanOrEqual(puzzle.difficulty.eloRange.lowerBound, 800)
        }
    }

    func testWarmupPuzzles_nonBandA_eloLowerBound_atLeast1000() {
        for band in [PlayerBand.bandB, .bandC, .bandD, .bandE] {
            for puzzle in ChessPuzzle.warmupPuzzles(for: band) {
                XCTAssertGreaterThanOrEqual(puzzle.difficulty.eloRange.lowerBound, 1000,
                    "Band \(band.rawValue) puzzle has ELO lower bound < 1000")
            }
        }
    }

    // MARK: - puzzleDatabase sanity

    func testPuzzleDatabase_notEmpty() {
        XCTAssertFalse(ChessPuzzle.puzzleDatabase.isEmpty)
    }

    func testPuzzleDatabase_allHaveNonEmptySolutions() {
        for puzzle in ChessPuzzle.puzzleDatabase {
            XCTAssertFalse(puzzle.solution.isEmpty, "Puzzle has empty solution")
        }
    }

    func testPuzzleDatabase_allHaveValidFEN() {
        for puzzle in ChessPuzzle.puzzleDatabase {
            XCTAssertNotNil(ChessBoard(fen: puzzle.fen),
                "Puzzle has invalid FEN: \(puzzle.fen)")
        }
    }
}
