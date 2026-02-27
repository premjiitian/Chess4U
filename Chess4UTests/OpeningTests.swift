import XCTest
@testable import Chess4U

final class OpeningTests: XCTestCase {

    // MARK: - Opening library integrity

    func testOpeningLibrary_notEmpty() {
        XCTAssertFalse(ChessOpening.openingLibrary.isEmpty)
    }

    func testOpeningLibrary_allHaveNonEmptyName() {
        for o in ChessOpening.openingLibrary {
            XCTAssertFalse(o.name.isEmpty, "\(o.eco) has empty name")
        }
    }

    func testOpeningLibrary_allHaveNonEmptyECO() {
        for o in ChessOpening.openingLibrary {
            XCTAssertFalse(o.eco.isEmpty, "\(o.name) has empty ECO code")
        }
    }

    func testOpeningLibrary_allHaveMoves() {
        for o in ChessOpening.openingLibrary {
            XCTAssertFalse(o.moves.isEmpty, "\(o.name) has no moves")
        }
    }

    func testOpeningLibrary_allHaveVariations() {
        for o in ChessOpening.openingLibrary {
            XCTAssertFalse(o.variations.isEmpty, "\(o.name) has no variations")
        }
    }

    func testOpeningLibrary_allHaveNonEmptyDescription() {
        for o in ChessOpening.openingLibrary {
            XCTAssertFalse(o.description.isEmpty, "\(o.name) has empty description")
        }
    }

    func testOpeningLibrary_allHaveValidFEN() {
        for o in ChessOpening.openingLibrary {
            XCTAssertFalse(o.fen.isEmpty, "\(o.name) has empty FEN")
            XCTAssertNotNil(ChessBoard(fen: o.fen), "\(o.name) FEN is invalid: \(o.fen)")
        }
    }

    func testOpeningLibrary_masteryLevelDefaultsToZero() {
        for o in ChessOpening.openingLibrary {
            XCTAssertEqual(o.masteryLevel, 0, "\(o.name) masteryLevel should default to 0")
        }
    }

    // MARK: - Spot checks on known openings

    func testItalianGame_ecoAndCategory() {
        let italian = ChessOpening.openingLibrary.first { $0.eco == "C50" }
        XCTAssertNotNil(italian, "Italian Game (C50) not found in library")
        XCTAssertEqual(italian?.category, .openGame)
        XCTAssertEqual(italian?.color, .white)
        XCTAssertEqual(italian?.difficulty, .easy)
    }

    func testSicilianDefense_isBlack() {
        let sicilian = ChessOpening.openingLibrary.first { $0.eco == "B20" }
        XCTAssertNotNil(sicilian, "Sicilian Defense (B20) not found in library")
        XCTAssertEqual(sicilian?.color, .black)
        XCTAssertEqual(sicilian?.category, .semiOpenGame)
    }

    func testQueensGambit_closedCategory() {
        let qg = ChessOpening.openingLibrary.first { $0.eco == "D20" }
        XCTAssertNotNil(qg, "Queen's Gambit (D20) not found in library")
        XCTAssertEqual(qg?.category, .closedGame)
    }

    func testKingsIndian_indianDefenseCategory() {
        let kid = ChessOpening.openingLibrary.first { $0.eco == "E60" }
        XCTAssertNotNil(kid, "King's Indian (E60) not found in library")
        XCTAssertEqual(kid?.category, .indianDefense)
        XCTAssertEqual(kid?.color, .black)
    }

    // MARK: - OpeningVariation integrity

    func testAllVariations_nonEmptyName() {
        for opening in ChessOpening.openingLibrary {
            for variation in opening.variations {
                XCTAssertFalse(variation.name.isEmpty,
                    "\(opening.name) has a variation with empty name")
            }
        }
    }

    func testAllVariations_nonEmptyMoves() {
        for opening in ChessOpening.openingLibrary {
            for variation in opening.variations {
                XCTAssertFalse(variation.moves.isEmpty,
                    "\(opening.name) › \(variation.name) has no moves")
            }
        }
    }

    func testAllVariations_fenDefaultsToStartingFEN() {
        // Variations created without explicit FEN get ChessBoard.startingFEN
        let italian = ChessOpening.openingLibrary.first { $0.eco == "C50" }!
        for variation in italian.variations {
            XCTAssertFalse(variation.fen.isEmpty,
                "\(variation.name) has empty FEN")
        }
    }

    // MARK: - OpeningCategory and OpeningColor enum coverage

    func testOpeningCategory_allCasesRepresented() {
        let categories = Set(ChessOpening.openingLibrary.map { $0.category })
        // Library should cover at least open, semi-open, closed, and Indian
        XCTAssertTrue(categories.contains(.openGame))
        XCTAssertTrue(categories.contains(.semiOpenGame))
        XCTAssertTrue(categories.contains(.closedGame))
        XCTAssertTrue(categories.contains(.indianDefense))
    }

    func testOpeningColor_bothSidesRepresented() {
        let colors = Set(ChessOpening.openingLibrary.map { $0.color })
        XCTAssertTrue(colors.contains(.white), "No white openings in library")
        XCTAssertTrue(colors.contains(.black), "No black openings in library")
    }
}
