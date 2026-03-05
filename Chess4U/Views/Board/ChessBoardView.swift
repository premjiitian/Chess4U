import SwiftUI

struct ChessBoardView: View {
    @ObservedObject var vm: ChessBoardViewModel
    let interactive: Bool
    @State private var showPromotion: Bool = false

    init(vm: ChessBoardViewModel, interactive: Bool = true) {
        self.vm = vm
        self.interactive = interactive
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.settings.showCoordinates {
                rankLabels
            }
            HStack(spacing: 0) {
                if vm.settings.showCoordinates {
                    fileLabels
                }
                boardGrid
            }
        }
        .overlay(promotionOverlay)
        .overlay(aiThinkingOverlay)
    }

    var boardGrid: some View {
        GeometryReader { geo in
            let squareSize = min(geo.size.width, geo.size.height) / 8
            ZStack(alignment: .topLeading) {
                // Board squares
                ForEach(0..<8, id: \.self) { file in
                    ForEach(0..<8, id: \.self) { rank in
                        let displayFile = vm.isFlipped ? 7 - file : file
                        let displayRank = vm.isFlipped ? rank : 7 - rank
                        let square = Square(displayFile, displayRank)

                        ChessSquareView(
                            square: square,
                            squareSize: squareSize,
                            piece: vm.game.board[square],
                            isSelected: vm.isSelected(square),
                            isLegalMove: vm.isLegalMove(square),
                            isLastMove: vm.isLastMove(square),
                            highlightColor: vm.highlightedSquares[square],
                            lightColor: vm.squareColor(file: displayFile, rank: displayRank)
                        )
                        .position(x: CGFloat(file) * squareSize + squareSize / 2,
                                  y: CGFloat(rank) * squareSize + squareSize / 2)
                        .onTapGesture {
                            if interactive {
                                handleTap(square: square, vm: vm)
                            }
                        }
                    }
                }

                // Arrows overlay
                ArrowsView(arrows: vm.arrows, squareSize: squareSize, isFlipped: vm.isFlipped)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }

    func handleTap(square: Square, vm: ChessBoardViewModel) {
        // Check if a move is being made to the tapped square
        if let selected = vm.selectedSquare, vm.isLegalMove(square) {
            let board = vm.game.board
            if let piece = board[selected], piece.type == .pawn {
                let promotionRank = piece.color == .white ? 7 : 0
                if square.rank == promotionRank {
                    vm.selectedSquare = selected
                    vm.promotionPending = square
                    showPromotion = true
                    return
                }
            }
        }
        vm.selectSquare(square)

        // After selection, check if move should be executed
        if let selected = vm.selectedSquare,
           let prevSelected = vm.selectedSquare,
           selected == prevSelected { }

        // If move was made, check if AI should respond
        if vm.game.board.activeColor == .black && interactive {
            // AI plays after player move
        }
    }

    var rankLabels: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 16)
            ForEach(0..<8, id: \.self) { file in
                let f = vm.isFlipped ? 7 - file : file
                Text(String("abcdefgh"[String.Index(utf16Offset: f, in: "abcdefgh")]))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 16)
    }

    var fileLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { rank in
                let r = vm.isFlipped ? rank : 7 - rank
                Text("\(r + 1)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 16)
    }

    var promotionOverlay: some View {
        Group {
            if vm.promotionPending != nil {
                PromotionView(
                    color: vm.game.board.activeColor,
                    onSelect: { piece in
                        vm.handlePromotion(piece: piece)
                        showPromotion = false
                    }
                )
            }
        }
    }

    var aiThinkingOverlay: some View {
        Group {
            if vm.isAIThinking {
                ZStack {
                    Color.black.opacity(0.3)
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                        Text("AI is thinking...")
                            .foregroundColor(.white)
                            .font(.subheadline)
                    }
                }
                .cornerRadius(4)
            }
        }
    }
}

// MARK: - Chess Square View
struct ChessSquareView: View {
    let square: Square
    let squareSize: CGFloat
    let piece: ChessPiece?
    let isSelected: Bool
    let isLegalMove: Bool
    let isLastMove: Bool
    let highlightColor: Color?
    let lightColor: Color

    var body: some View {
        ZStack {
            // Square background
            Rectangle()
                .fill(backgroundColor)
                .frame(width: squareSize, height: squareSize)

            // Legal move indicator
            if isLegalMove {
                if piece != nil {
                    Circle()
                        .stroke(Color.blue.opacity(0.6), lineWidth: squareSize * 0.08)
                        .frame(width: squareSize * 0.9, height: squareSize * 0.9)
                } else {
                    Circle()
                        .fill(Color.blue.opacity(0.35))
                        .frame(width: squareSize * 0.33, height: squareSize * 0.33)
                }
            }

            // Piece — rendered with high-contrast outline so white pieces are
            // always visible on light squares and black pieces on dark squares.
            if let piece = piece {
                let fontSize = squareSize * (piece.type == .pawn ? 0.64 : 0.78)
                ZStack {
                    // Blurred dark silhouette creates a natural outline/border
                    // that makes white pieces pop against any square color.
                    Text(piece.symbolForColor)
                        .font(.system(size: fontSize))
                        .foregroundColor(Color(white: 0.05).opacity(piece.color == .white ? 0.75 : 0.35))
                        .blur(radius: squareSize * 0.04)
                    // Primary glyph layer with explicit piece-color foreground
                    Text(piece.symbolForColor)
                        .font(.system(size: fontSize))
                        .minimumScaleFactor(0.5)
                        .foregroundColor(piece.color == .white
                            ? Color(white: 0.97)
                            : Color(white: 0.06))
                }
            }
        }
    }

    var backgroundColor: Color {
        if let h = highlightColor { return h.opacity(0.7) }
        if isSelected { return Color.yellow.opacity(0.7) }
        if isLastMove { return Color.yellow.opacity(0.4) }
        return lightColor
    }
}

// MARK: - Arrows View
struct ArrowsView: View {
    let arrows: [(Square, Square)]
    let squareSize: CGFloat
    let isFlipped: Bool

    var body: some View {
        Canvas { context, size in
            for (from, to) in arrows {
                let fromPoint = center(of: from, squareSize: squareSize, isFlipped: isFlipped)
                let toPoint = center(of: to, squareSize: squareSize, isFlipped: isFlipped)
                drawArrow(context: context, from: fromPoint, to: toPoint)
            }
        }
    }

    private func center(of square: Square, squareSize: CGFloat, isFlipped: Bool) -> CGPoint {
        let file = isFlipped ? 7 - square.file : square.file
        let rank = isFlipped ? square.rank : 7 - square.rank
        return CGPoint(x: CGFloat(file) * squareSize + squareSize / 2,
                       y: CGFloat(rank) * squareSize + squareSize / 2)
    }

    private func drawArrow(context: GraphicsContext, from: CGPoint, to: CGPoint) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return }

        let angle = atan2(dy, dx)
        let arrowLength = squareSize * 0.35
        let arrowWidth = squareSize * 0.15

        var path = Path()
        path.move(to: from)
        path.addLine(to: CGPoint(x: to.x - arrowLength * cos(angle),
                                 y: to.y - arrowLength * sin(angle)))
        context.stroke(path, with: .color(.orange.opacity(0.8)), lineWidth: arrowWidth)

        var arrowHead = Path()
        arrowHead.move(to: to)
        arrowHead.addLine(to: CGPoint(x: to.x - arrowLength * cos(angle - .pi / 6),
                                      y: to.y - arrowLength * sin(angle - .pi / 6)))
        arrowHead.addLine(to: CGPoint(x: to.x - arrowLength * cos(angle + .pi / 6),
                                      y: to.y - arrowLength * sin(angle + .pi / 6)))
        arrowHead.closeSubpath()
        context.fill(arrowHead, with: .color(.orange.opacity(0.9)))
    }
}

// MARK: - Promotion View
struct PromotionView: View {
    let color: PieceColor
    let onSelect: (PieceType) -> Void
    private let pieces: [PieceType] = [.queen, .rook, .bishop, .knight]

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
            VStack(spacing: 12) {
                Text("Choose Promotion")
                    .font(.headline)
                    .foregroundColor(.white)
                HStack(spacing: 12) {
                    ForEach(pieces, id: \.self) { piece in
                        let chessPiece = ChessPiece(type: piece, color: color)
                        Button {
                            onSelect(piece)
                        } label: {
                            Text(chessPiece.symbolForColor)
                                .font(.system(size: 48))
                                .frame(width: 70, height: 70)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                        }
                    }
                }
            }
            .padding()
        }
        .cornerRadius(16)
    }
}
