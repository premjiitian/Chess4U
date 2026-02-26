import SwiftUI

// MARK: - Chess Piece Types
enum PieceType: String, Codable, CaseIterable, Equatable {
    case king = "King"
    case queen = "Queen"
    case rook = "Rook"
    case bishop = "Bishop"
    case knight = "Knight"
    case pawn = "Pawn"

    var symbol: String {
        switch self {
        case .king: return "♔"
        case .queen: return "♕"
        case .rook: return "♖"
        case .bishop: return "♗"
        case .knight: return "♘"
        case .pawn: return "♙"
        }
    }

    var value: Int {
        switch self {
        case .pawn: return 1
        case .knight: return 3
        case .bishop: return 3
        case .rook: return 5
        case .queen: return 9
        case .king: return 0
        }
    }

    var fenChar: Character {
        switch self {
        case .king: return "k"
        case .queen: return "q"
        case .rook: return "r"
        case .bishop: return "b"
        case .knight: return "n"
        case .pawn: return "p"
        }
    }
}

enum PieceColor: String, Codable, CaseIterable, Equatable {
    case white
    case black

    var opposite: PieceColor { self == .white ? .black : .white }
}

// MARK: - Chess Piece
struct ChessPiece: Codable, Equatable, Identifiable {
    let id: UUID
    var type: PieceType
    var color: PieceColor
    var hasMoved: Bool

    init(type: PieceType, color: PieceColor, hasMoved: Bool = false) {
        self.id = UUID()
        self.type = type
        self.color = color
        self.hasMoved = hasMoved
    }

    var symbolForColor: String {
        let base: String
        switch type {
        case .king:   base = color == .white ? "♔" : "♚"
        case .queen:  base = color == .white ? "♕" : "♛"
        case .rook:   base = color == .white ? "♖" : "♜"
        case .bishop: base = color == .white ? "♗" : "♝"
        case .knight: base = color == .white ? "♘" : "♞"
        case .pawn:   base = color == .white ? "♙" : "♟"
        }
        return base
    }

    var sfName: String {
        let colorPrefix = color == .white ? "w" : "b"
        switch type {
        case .king:   return "\(colorPrefix)K"
        case .queen:  return "\(colorPrefix)Q"
        case .rook:   return "\(colorPrefix)R"
        case .bishop: return "\(colorPrefix)B"
        case .knight: return "\(colorPrefix)N"
        case .pawn:   return "\(colorPrefix)P"
        }
    }
}

// MARK: - Board Square
struct Square: Hashable, Codable, Equatable {
    let file: Int  // 0-7 (a-h)
    let rank: Int  // 0-7 (1-8)

    init(_ file: Int, _ rank: Int) {
        self.file = file
        self.rank = rank
    }

    init?(algebraic: String) {
        guard algebraic.count == 2,
              let fileChar = algebraic.first,
              let rankChar = algebraic.last,
              let file = "abcdefgh".firstIndex(of: fileChar),
              let rank = Int(String(rankChar)),
              (1...8).contains(rank) else { return nil }
        self.file = "abcdefgh".distance(from: "abcdefgh".startIndex, to: file)
        self.rank = rank - 1
    }

    var algebraic: String {
        let fileChar = "abcdefgh"[String.Index(utf16Offset: file, in: "abcdefgh")]
        return "\(fileChar)\(rank + 1)"
    }

    var isValid: Bool { (0...7).contains(file) && (0...7).contains(rank) }

    func offset(file df: Int, rank dr: Int) -> Square {
        Square(file + df, rank + dr)
    }
}
