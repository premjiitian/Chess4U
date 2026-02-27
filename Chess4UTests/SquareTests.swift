import XCTest
@testable import Chess4U

final class SquareTests: XCTestCase {

    // MARK: - algebraic property

    func testAlgebraic_a1() { XCTAssertEqual(Square(0, 0).algebraic, "a1") }
    func testAlgebraic_h8() { XCTAssertEqual(Square(7, 7).algebraic, "h8") }
    func testAlgebraic_e4() { XCTAssertEqual(Square(4, 3).algebraic, "e4") }
    func testAlgebraic_c6() { XCTAssertEqual(Square(2, 5).algebraic, "c6") }

    // MARK: - init(algebraic:)

    func testAlgebraicInit_a1() {
        let sq = Square(algebraic: "a1")
        XCTAssertEqual(sq?.file, 0)
        XCTAssertEqual(sq?.rank, 0)
    }

    func testAlgebraicInit_h8() {
        let sq = Square(algebraic: "h8")
        XCTAssertEqual(sq?.file, 7)
        XCTAssertEqual(sq?.rank, 7)
    }

    func testAlgebraicInit_invalid() {
        XCTAssertNil(Square(algebraic: ""))
        XCTAssertNil(Square(algebraic: "a9"))
        XCTAssertNil(Square(algebraic: "i1"))
        XCTAssertNil(Square(algebraic: "abc"))
    }

    // MARK: - isValid

    func testIsValid_validSquares() {
        XCTAssertTrue(Square(0, 0).isValid)
        XCTAssertTrue(Square(7, 7).isValid)
        XCTAssertTrue(Square(4, 3).isValid)
    }

    func testIsValid_invalidSquares() {
        XCTAssertFalse(Square(-1, 0).isValid)
        XCTAssertFalse(Square(0, -1).isValid)
        XCTAssertFalse(Square(8, 0).isValid)
        XCTAssertFalse(Square(0, 8).isValid)
    }

    // MARK: - offset

    func testOffset_positive() {
        let sq = Square(3, 3).offset(file: 2, rank: 1)
        XCTAssertEqual(sq.file, 5)
        XCTAssertEqual(sq.rank, 4)
    }

    func testOffset_negative() {
        let sq = Square(4, 4).offset(file: -2, rank: -3)
        XCTAssertEqual(sq.file, 2)
        XCTAssertEqual(sq.rank, 1)
    }

    func testOffset_outOfBounds_isInvalid() {
        XCTAssertFalse(Square(0, 0).offset(file: -1, rank: 0).isValid)
        XCTAssertFalse(Square(7, 7).offset(file: 1, rank: 0).isValid)
    }

    // MARK: - Equatable

    func testEquality() {
        XCTAssertEqual(Square(3, 4), Square(3, 4))
        XCTAssertNotEqual(Square(3, 4), Square(4, 3))
    }

    // MARK: - Roundtrip

    func testAlgebraicRoundtrip() {
        let squares = [Square(0, 0), Square(7, 7), Square(4, 3), Square(2, 5)]
        for sq in squares {
            guard let parsed = Square(algebraic: sq.algebraic) else {
                XCTFail("Failed to parse \(sq.algebraic)"); continue
            }
            XCTAssertEqual(parsed, sq)
        }
    }
}
