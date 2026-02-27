import XCTest
@testable import Chess4U

final class ChessMoveTests: XCTestCase {

    private let whitePawn   = ChessPiece(type: .pawn,   color: .white)
    private let whiteKnight = ChessPiece(type: .knight, color: .white)
    private let blackRook   = ChessPiece(type: .rook,   color: .black)

    // MARK: - ChessMove.isCapture

    func testIsCapture_falseWhenNoCapturedPiece() {
        let move = ChessMove(from: Square(4, 1), to: Square(4, 3), piece: whitePawn)
        XCTAssertFalse(move.isCapture)
    }

    func testIsCapture_trueWhenCapturedPieceSet() {
        let move = ChessMove(from: Square(4, 4), to: Square(3, 5), piece: whitePawn,
                             capturedPiece: blackRook)
        XCTAssertTrue(move.isCapture)
    }

    func testIsCapture_trueWhenEnPassant() {
        let move = ChessMove(from: Square(4, 4), to: Square(3, 5), piece: whitePawn,
                             isEnPassant: true)
        XCTAssertTrue(move.isCapture)
    }

    // MARK: - ChessMove.longAlgebraic

    func testLongAlgebraic_e2e4() {
        let move = ChessMove(from: Square(4, 1), to: Square(4, 3), piece: whitePawn)
        XCTAssertEqual(move.longAlgebraic, "e2e4")
    }

    func testLongAlgebraic_kingsideCastle() {
        let king = ChessPiece(type: .king, color: .white)
        let move = ChessMove(from: Square(4, 0), to: Square(6, 0), piece: king, isCastling: true)
        XCTAssertEqual(move.longAlgebraic, "e1g1")
    }

    func testLongAlgebraic_queensideCastle() {
        let king = ChessPiece(type: .king, color: .white)
        let move = ChessMove(from: Square(4, 0), to: Square(2, 0), piece: king, isCastling: true)
        XCTAssertEqual(move.longAlgebraic, "e1c1")
    }

    // MARK: - MoveAnnotation.icon

    func testAnnotation_iconEqualsRawValue() {
        for annotation in MoveAnnotation.allCases {
            XCTAssertEqual(annotation.icon, annotation.rawValue)
        }
    }

    // MARK: - MoveAnnotation.color

    func testAnnotation_best_isGreen()      { XCTAssertEqual(MoveAnnotation.best.color,        "green") }
    func testAnnotation_good_isGreen()      { XCTAssertEqual(MoveAnnotation.good.color,        "green") }
    func testAnnotation_interesting_isBlue(){ XCTAssertEqual(MoveAnnotation.interesting.color, "blue") }
    func testAnnotation_dubious_isOrange()  { XCTAssertEqual(MoveAnnotation.dubious.color,     "orange") }
    func testAnnotation_mistake_isRed()     { XCTAssertEqual(MoveAnnotation.mistake.color,     "red") }
    func testAnnotation_blunder_isRed()     { XCTAssertEqual(MoveAnnotation.blunder.color,     "red") }

    // MARK: - MoveAnnotation.description

    func testAnnotation_allHaveNonEmptyDescription() {
        for annotation in MoveAnnotation.allCases {
            XCTAssertFalse(annotation.description.isEmpty, "\(annotation) has empty description")
        }
    }

    // MARK: - MoveTreeNode

    func testMoveTreeNode_isLeaf_whenNoChildren() {
        let root = MoveTreeNode()
        XCTAssertTrue(root.isLeaf)
        XCTAssertNil(root.mainContinuation)
    }

    func testMoveTreeNode_addChild_setsParentAndDepth() {
        let root  = MoveTreeNode()
        let child = MoveTreeNode(move: ChessMove(from: Square(4, 1), to: Square(4, 3), piece: whitePawn))
        root.addChild(child)
        XCTAssertTrue(root.children.contains { $0 === child })
        XCTAssertTrue(child.parent === root)
        XCTAssertEqual(child.depth, 1)
    }

    func testMoveTreeNode_firstChildIsMainLine() {
        let root   = MoveTreeNode()
        let child1 = MoveTreeNode()
        let child2 = MoveTreeNode()
        root.addChild(child1)
        root.addChild(child2)
        XCTAssertTrue(child1.isMainLine)
        XCTAssertFalse(child2.isMainLine)
        XCTAssertTrue(root.mainContinuation === child1)
    }

    func testMoveTreeNode_notLeaf_afterAddChild() {
        let root  = MoveTreeNode()
        let child = MoveTreeNode()
        root.addChild(child)
        XCTAssertFalse(root.isLeaf)
    }
}
