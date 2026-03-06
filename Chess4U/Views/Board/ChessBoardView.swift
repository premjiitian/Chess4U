import SwiftUI

// MARK: - Chess Board View
/// The main interactive board view. Supports both tap-to-move (iOS standard) and
/// drag-and-drop piece movement (chess.com/lichess standard).
/// Optionally renders a vertical evaluation bar via `showEvalBar`.
struct ChessBoardView: View {
    @ObservedObject var vm: ChessBoardViewModel
    let interactive: Bool
    let showEvalBar: Bool
    @State private var showPromotion: Bool = false
    @State private var draggedPiece: ChessPiece? = nil
    @State private var draggedFrom: Square? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var dragLocation: CGPoint = .zero

    init(vm: ChessBoardViewModel, interactive: Bool = true, showEvalBar: Bool = false) {
        self.vm = vm
        self.interactive = interactive
        self.showEvalBar = showEvalBar
    }

    var body: some View {
        HStack(spacing: 0) {
            // Optional evaluation bar (left side, grandmaster / study mode)
            if showEvalBar {
                EvalBarView(evaluation: vm.currentEvaluation)
                    .frame(width: 14)
                    .padding(.trailing, 4)
            }

            VStack(spacing: 0) {
                if vm.settings.showCoordinates { rankLabels }
                HStack(spacing: 0) {
                    if vm.settings.showCoordinates { fileLabels }
                    boardGrid
                }
            }
        }
        .overlay(promotionOverlay)
        .overlay(aiThinkingOverlay)
    }

    // MARK: - Board Grid

    var boardGrid: some View {
        GeometryReader { geo in
            let squareSize = min(geo.size.width, geo.size.height) / 8
            ZStack(alignment: .topLeading) {
                // Squares + pieces
                ForEach(0..<8, id: \.self) { file in
                    ForEach(0..<8, id: \.self) { rank in
                        let displayFile = vm.isFlipped ? 7 - file : file
                        let displayRank = vm.isFlipped ? rank : 7 - rank
                        let square = Square(displayFile, displayRank)
                        let isDragging = draggedFrom == square

                        ChessSquareView(
                            square: square,
                            squareSize: squareSize,
                            piece: isDragging ? nil : vm.game.board[square],  // hide piece while dragging
                            isSelected: vm.isSelected(square),
                            isLegalMove: vm.isLegalMove(square),
                            isLastMove: vm.isLastMove(square),
                            highlightColor: vm.highlightedSquares[square],
                            lightColor: vm.squareColor(file: displayFile, rank: displayRank),
                            isActiveColor: vm.game.board[square]?.color == vm.game.board.activeColor,
                            isInteractive: interactive
                        )
                        .position(x: CGFloat(file) * squareSize + squareSize / 2,
                                  y: CGFloat(rank) * squareSize + squareSize / 2)
                        .onTapGesture {
                            if interactive { handleTap(square: square) }
                        }
                    }
                }

                // Arrows overlay
                ArrowsView(arrows: vm.arrows, squareSize: squareSize, isFlipped: vm.isFlipped)

                // Floating dragged piece
                if let piece = draggedPiece {
                    let fontSize = squareSize * (piece.type == .pawn ? 0.64 : 0.78)
                    ZStack {
                        Text(piece.symbolForColor)
                            .font(.system(size: fontSize))
                            .foregroundColor(piece.color == .white ? Color(white: 0.05).opacity(0.7) : Color(white: 0.1).opacity(0.3))
                            .blur(radius: squareSize * 0.04)
                        Text(piece.symbolForColor)
                            .font(.system(size: fontSize))
                            .foregroundColor(piece.color == .white ? Color(white: 0.97) : Color(white: 0.06))
                    }
                    .scaleEffect(1.25)  // Piece lifts up when dragged
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                    .position(dragLocation)
                    .allowsHitTesting(false)
                }
            }
            // MARK: Drag Gesture
            .gesture(
                interactive ?
                DragGesture(minimumDistance: 4, coordinateSpace: .local)
                    .onChanged { value in
                        dragLocation = value.location
                        let sq = squareAt(location: value.startLocation, squareSize: squareSize)

                        if draggedFrom == nil {
                            // Start drag — select the piece
                            if let piece = vm.game.board[sq], piece.color == vm.game.board.activeColor {
                                draggedFrom = sq
                                draggedPiece = piece
                                vm.selectedSquare = sq
                                vm.legalMoveSquares = ChessEngineService.shared
                                    .legalMoves(for: piece, at: sq, on: vm.game.board)
                                    .map { $0.to }
                                HapticService.shared.pieceSelected()
                            }
                        }
                    }
                    .onEnded { value in
                        let targetSq = squareAt(location: value.location, squareSize: squareSize)
                        if let fromSq = draggedFrom, targetSq != fromSq {
                            handleTap(square: targetSq)
                        } else {
                            // Cancelled drag — deselect
                            vm.selectedSquare = nil
                            vm.legalMoveSquares = []
                        }
                        draggedFrom = nil
                        draggedPiece = nil
                        dragOffset = .zero
                    }
                : nil
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Input Handling

    func handleTap(square: Square) {
        let board = vm.game.board

        // Promotion path
        if let selected = vm.selectedSquare, vm.isLegalMove(square) {
            if let piece = board[selected], piece.type == .pawn {
                let promotionRank = piece.color == .white ? 7 : 0
                if square.rank == promotionRank {
                    vm.selectedSquare = selected
                    vm.promotionPending = square
                    showPromotion = true
                    HapticService.shared.pieceMoved()
                    return
                }
            }
        }

        let prevMoveCount = vm.game.moves.count
        vm.selectSquare(square)
        let nowMoveCount = vm.game.moves.count

        if nowMoveCount > prevMoveCount, let lastMove = vm.game.moves.last {
            // A move was made — fire feedback
            fireMoveFeedback(move: lastMove)
        } else if vm.selectedSquare == square {
            // Piece selected
            HapticService.shared.pieceSelected()
        }
    }

    private func fireMoveFeedback(move: ChessMove) {
        if move.isCastling {
            HapticService.shared.castling()
            SoundService.shared.playCastling()
        } else if move.isCapture {
            HapticService.shared.pieceCapture()
            SoundService.shared.playCapture()
        } else {
            HapticService.shared.pieceMoved()
            SoundService.shared.playMove()
        }

        // Check / checkmate feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            switch vm.game.status {
            case .check:
                HapticService.shared.check()
                SoundService.shared.playCheck()
            case .checkmate:
                HapticService.shared.checkmate()
                SoundService.shared.playGameWon()
            default: break
            }
        }

        if move.promotionPiece != nil {
            HapticService.shared.promotion()
            SoundService.shared.playPromotion()
        }
    }

    // MARK: - Coordinate Conversion

    private func squareAt(location: CGPoint, squareSize: CGFloat) -> Square {
        let file = Int(location.x / squareSize).clamped(to: 0...7)
        let rank = Int(location.y / squareSize).clamped(to: 0...7)
        let displayFile = vm.isFlipped ? 7 - file : file
        let displayRank = vm.isFlipped ? rank : 7 - rank
        return Square(displayFile, displayRank)
    }

    // MARK: - Labels

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

    // MARK: - Overlays

    var promotionOverlay: some View {
        Group {
            if vm.promotionPending != nil {
                PromotionView(
                    color: vm.game.board.activeColor,
                    onSelect: { piece in
                        vm.handlePromotion(piece: piece)
                        showPromotion = false
                        HapticService.shared.promotion()
                        SoundService.shared.playPromotion()
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

// MARK: - Evaluation Bar View
/// Vertical bar showing the engine evaluation: white (top) vs black (bottom).
/// Clamped to ±5 pawns for display purposes.
struct EvalBarView: View {
    let evaluation: Double  // positive = white advantage, negative = black

    private var whiteRatio: CGFloat {
        let clamped = max(-5.0, min(5.0, evaluation))
        return CGFloat((clamped + 5.0) / 10.0)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Black side (full bar)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.12))

                // White side (grows from bottom)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.95))
                    .frame(height: geo.size.height * whiteRatio)

                // Advantage label
                let absEval = abs(evaluation)
                if absEval > 0.3 {
                    Text(absEval >= 10 ? "M" : String(format: "%.1f", absEval))
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(evaluation > 0 ? Color(white: 0.1) : .white)
                        .padding(.bottom, evaluation > 0 ? 3 : nil)
                        .padding(.top, evaluation <= 0 ? 3 : nil)
                        .frame(maxHeight: .infinity,
                               alignment: evaluation > 0 ? .bottom : .top)
                }
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
    var isActiveColor: Bool = false
    var isInteractive: Bool = true

    var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)
                .frame(width: squareSize, height: squareSize)

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

            // Piece — ZStack with blurred dark silhouette for white piece visibility
            if let piece = piece {
                let fontSize = squareSize * (piece.type == .pawn ? 0.64 : 0.78)
                ZStack {
                    Text(piece.symbolForColor)
                        .font(.system(size: fontSize))
                        .foregroundColor(Color(white: 0.05).opacity(piece.color == .white ? 0.75 : 0.35))
                        .blur(radius: squareSize * 0.04)
                    Text(piece.symbolForColor)
                        .font(.system(size: fontSize))
                        .minimumScaleFactor(0.5)
                        .foregroundColor(piece.color == .white
                            ? Color(white: 0.97)
                            : Color(white: 0.06))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(squareAccessibilityLabel)
        .accessibilityHint(squareAccessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Accessibility

    private var squareAccessibilityLabel: String {
        if isLegalMove && piece == nil {
            return "Legal move: \(square.algebraic)"
        }
        if let piece = piece {
            let colorName = piece.color == .white ? "White" : "Black"
            var label = "\(colorName) \(piece.type.rawValue) on \(square.algebraic)"
            if isSelected { label += ", selected" }
            if isLegalMove { label += ", can capture here" }
            if isLastMove  { label += ", last move" }
            return label
        }
        return isLastMove ? "Last move to \(square.algebraic)" : "\(square.algebraic)"
    }

    private var squareAccessibilityHint: String {
        if isLegalMove { return "Double tap to move here" }
        if piece != nil && isActiveColor && isInteractive {
            return isSelected ? "Double tap to deselect" : "Double tap to select"
        }
        return ""
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
        let dx = to.x - from.x, dy = to.y - from.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return }
        let angle = atan2(dy, dx)
        let arrowLength = squareSize * 0.35
        let arrowWidth  = squareSize * 0.15

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

// MARK: - Int Clamping Helper
extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
