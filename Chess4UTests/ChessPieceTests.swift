import XCTest
@testable import Chess4U

final class ChessPieceTests: XCTestCase {

    // MARK: - PieceType.value

    func testPieceValue_pawn()   { XCTAssertEqual(PieceType.pawn.value,   1) }
    func testPieceValue_knight() { XCTAssertEqual(PieceType.knight.value, 3) }
    func testPieceValue_bishop() { XCTAssertEqual(PieceType.bishop.value, 3) }
    func testPieceValue_rook()   { XCTAssertEqual(PieceType.rook.value,   5) }
    func testPieceValue_queen()  { XCTAssertEqual(PieceType.queen.value,  9) }
    func testPieceValue_king()   { XCTAssertEqual(PieceType.king.value,   0) }

    // MARK: - PieceType.fenChar

    func testFenChar_casesAreLowercase() {
        for type in PieceType.allCases {
            let ch = type.fenChar
            XCTAssertTrue(ch.isLowercase, "\(type) fenChar '\(ch)' is not lowercase")
        }
    }

    func testFenChar_spotChecks() {
        XCTAssertEqual(PieceType.king.fenChar,   "k")
        XCTAssertEqual(PieceType.queen.fenChar,  "q")
        XCTAssertEqual(PieceType.rook.fenChar,   "r")
        XCTAssertEqual(PieceType.bishop.fenChar, "b")
        XCTAssertEqual(PieceType.knight.fenChar, "n")
        XCTAssertEqual(PieceType.pawn.fenChar,   "p")
    }

    // MARK: - PieceType.symbol

    func testSymbol_allNonEmpty() {
        for type in PieceType.allCases {
            XCTAssertFalse(type.symbol.isEmpty, "\(type).symbol is empty")
        }
    }

    func testSymbol_kingIsWhiteKingUnicode() {
        XCTAssertEqual(PieceType.king.symbol, "♔")
    }

    // MARK: - PieceColor.opposite

    func testOpposite_whiteIsBlack() { XCTAssertEqual(PieceColor.white.opposite, .black) }
    func testOpposite_blackIsWhite() { XCTAssertEqual(PieceColor.black.opposite, .white) }
    func testOpposite_involution()   { XCTAssertEqual(PieceColor.white.opposite.opposite, .white) }

    // MARK: - ChessPiece.symbolForColor

    func testSymbolForColor_whiteKing()  { XCTAssertEqual(ChessPiece(type: .king,   color: .white).symbolForColor, "♔") }
    func testSymbolForColor_blackKing()  { XCTAssertEqual(ChessPiece(type: .king,   color: .black).symbolForColor, "♚") }
    func testSymbolForColor_whitePawn()  { XCTAssertEqual(ChessPiece(type: .pawn,   color: .white).symbolForColor, "♙") }
    func testSymbolForColor_blackPawn()  { XCTAssertEqual(ChessPiece(type: .pawn,   color: .black).symbolForColor, "♟") }
    func testSymbolForColor_whiteQueen() { XCTAssertEqual(ChessPiece(type: .queen,  color: .white).symbolForColor, "♕") }
    func testSymbolForColor_blackRook()  { XCTAssertEqual(ChessPiece(type: .rook,   color: .black).symbolForColor, "♜") }

    // MARK: - ChessPiece.sfName

    func testSfName_whiteKing()   { XCTAssertEqual(ChessPiece(type: .king,   color: .white).sfName, "wK") }
    func testSfName_blackQueen()  { XCTAssertEqual(ChessPiece(type: .queen,  color: .black).sfName, "bQ") }
    func testSfName_whiteKnight() { XCTAssertEqual(ChessPiece(type: .knight, color: .white).sfName, "wN") }
    func testSfName_blackPawn()   { XCTAssertEqual(ChessPiece(type: .pawn,   color: .black).sfName, "bP") }

    // MARK: - ChessPiece.hasMoved default

    func testHasMoved_defaultFalse() {
        let piece = ChessPiece(type: .rook, color: .white)
        XCTAssertFalse(piece.hasMoved)
    }

    func testHasMoved_canBeSetTrue() {
        let piece = ChessPiece(type: .rook, color: .white, hasMoved: true)
        XCTAssertTrue(piece.hasMoved)
    }
}
