import Foundation

// MARK: - Chess Move
struct ChessMove: Codable, Equatable, Identifiable {
    let id: UUID
    var from: Square
    var to: Square
    var piece: ChessPiece
    var capturedPiece: ChessPiece?
    var promotionPiece: PieceType?
    var isCastling: Bool
    var isEnPassant: Bool
    var notation: String
    var annotation: MoveAnnotation?
    var comment: String?

    init(from: Square, to: Square, piece: ChessPiece,
         capturedPiece: ChessPiece? = nil, promotionPiece: PieceType? = nil,
         isCastling: Bool = false, isEnPassant: Bool = false,
         notation: String = "", annotation: MoveAnnotation? = nil) {
        self.id = UUID()
        self.from = from
        self.to = to
        self.piece = piece
        self.capturedPiece = capturedPiece
        self.promotionPiece = promotionPiece
        self.isCastling = isCastling
        self.isEnPassant = isEnPassant
        self.notation = notation
        self.annotation = annotation
    }

    var isCapture: Bool { capturedPiece != nil || isEnPassant }
    var isPromotion: Bool { promotionPiece != nil }

    var longAlgebraic: String {
        return "\(from.algebraic)\(to.algebraic)"
    }
}

// MARK: - Move Annotation
enum MoveAnnotation: String, Codable, CaseIterable {
    case best = "!!"       // Brilliant
    case good = "!"        // Good
    case interesting = "!?"  // Interesting
    case dubious = "?!"    // Dubious
    case mistake = "?"     // Mistake
    case blunder = "??"    // Blunder

    var icon: String { rawValue }

    var color: String {
        switch self {
        case .best, .good: return "green"
        case .interesting: return "blue"
        case .dubious: return "orange"
        case .mistake: return "red"
        case .blunder: return "red"
        }
    }

    var description: String {
        switch self {
        case .best: return "Brilliant move"
        case .good: return "Good move"
        case .interesting: return "Interesting move"
        case .dubious: return "Dubious move"
        case .mistake: return "Mistake"
        case .blunder: return "Blunder"
        }
    }
}

// MARK: - Game Phase
enum GamePhase: String, Codable {
    case opening = "Opening"
    case middlegame = "Middlegame"
    case endgame = "Endgame"
}

// MARK: - Move Tree Node (for Variation Practice)
class MoveTreeNode: Identifiable, ObservableObject {
    let id = UUID()
    var move: ChessMove?
    var comment: String?
    var annotation: MoveAnnotation?
    var children: [MoveTreeNode] = []
    weak var parent: MoveTreeNode?
    var isMainLine: Bool = true
    var depth: Int = 0

    init(move: ChessMove? = nil, comment: String? = nil) {
        self.move = move
        self.comment = comment
    }

    func addChild(_ node: MoveTreeNode) {
        node.parent = self
        node.depth = depth + 1
        if children.isEmpty {
            node.isMainLine = true
        } else {
            node.isMainLine = false
        }
        children.append(node)
    }

    var isLeaf: Bool { children.isEmpty }
    var mainContinuation: MoveTreeNode? { children.first }
}
