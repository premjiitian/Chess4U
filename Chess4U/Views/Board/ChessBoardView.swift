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
                            isInteractive: interactive,
                            pieceStyle: vm.settings.pieceStyle
                        )
                        .position(x: CGFloat(file) * squareSize + squareSize / 2,
                                  y: CGFloat(rank) * squareSize + squareSize / 2)
                        .accessibilityAction(.default) {
                            if interactive { handleTap(square: square) }
                        }
                    }
                }

                // Arrows overlay
                ArrowsView(arrows: vm.arrows, squareSize: squareSize, isFlipped: vm.isFlipped)

                // Floating dragged piece
                if let piece = draggedPiece {
                    let fontSize = squareSize * piece.type.boardSizeFactor
                    ChessPieceGlyph(piece: piece, fontSize: fontSize, pieceStyle: vm.settings.pieceStyle)
                        .scaleEffect(1.25)  // Piece lifts up when dragged
                        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                        .position(dragLocation)
                        .allowsHitTesting(false)
                }
            }
            // MARK: Unified Tap + Drag Gesture
            // A single gesture recognizer handles both tap-to-move and drag-and-drop.
            // Using minimumDistance: 0 (rather than splitting tap/drag across two
            // competing recognizers) means every touch — tap or drag — flows through
            // the same state machine, so a simple tap can never get silently swallowed
            // or "cancelled" by a sibling drag recognizer.
            .gesture(
                interactive ?
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        dragLocation = value.location
                        let distance = hypot(value.translation.width, value.translation.height)
                        let startSq = squareAt(location: value.startLocation, squareSize: squareSize)

                        // Only "pick up" the piece visually once the finger has moved far
                        // enough to be a genuine drag — this keeps plain taps from ever
                        // triggering drag state.
                        if draggedFrom == nil, distance > squareSize * 0.15,
                           let piece = vm.game.board[startSq], piece.color == vm.game.board.activeColor {
                            draggedFrom = startSq
                            draggedPiece = piece
                            if vm.selectedSquare != startSq {
                                vm.selectSquare(startSq)
                                HapticService.shared.pieceSelected()
                            }
                        }
                    }
                    .onEnded { value in
                        let distance = hypot(value.translation.width, value.translation.height)
                        let startSq = squareAt(location: value.startLocation, squareSize: squareSize)
                        let endSq = squareAt(location: value.location, squareSize: squareSize)

                        if distance <= squareSize * 0.15 {
                            // A plain tap: select the piece, or move if a destination
                            // square was already selected.
                            handleTap(square: startSq)
                        } else if let fromSq = draggedFrom, endSq != fromSq {
                            // A genuine drag that ended on a different square.
                            handleTap(square: endSq)
                        }
                        // Dropped back on the same square after a real drag: leave the
                        // current selection as-is (matches chess.com behavior).

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
                    },
                    pieceStyle: vm.settings.pieceStyle
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
    var pieceStyle: PieceStyle = .standard

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

            // Piece — solid silhouette + contrasting outline, chess.com/Lichess style
            if let piece = piece {
                let fontSize = squareSize * piece.type.boardSizeFactor
                ChessPieceGlyph(piece: piece, fontSize: fontSize, pieceStyle: pieceStyle)
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

// MARK: - Chess Piece Glyph
/// Renders a chess piece as a solid, outlined silhouette -- the same approach
/// chess.com and Lichess piece sets use (a filled shape + a contrasting
/// border) rather than relying on a font's built-in glyph shading.
/// `ChessPiece.symbolForColor` always returns the solid glyph variant
/// regardless of color; this view turns that single shape into a properly
/// legible white-or-black piece with a same-shape, larger duplicate glyph in
/// the outline color placed directly behind the normal-size fill glyph (see
/// `outlineScale`) -- two flat layers, no blur, no offset copies, so there's
/// no room for anti-aliasing at small (pawn) sizes to blend the two colors
/// toward each other.
struct ChessPieceGlyph: View {
    let piece: ChessPiece
    let fontSize: CGFloat
    /// Which of the four named piece sets (Settings > Piece Style) to render.
    /// Since the app draws pieces from styled Unicode glyphs rather than
    /// bundled artwork, each style is differentiated by palette and outline
    /// weight, not a different glyph shape.
    var pieceStyle: PieceStyle = .standard

    /// Deliberately at the extremes (pure white / pure black) for .standard
    /// and .neo -- previous, slightly-off-white/off-black values (0.99/0.08)
    /// left enough room for anti-aliasing at small (pawn) sizes to blend the
    /// fill toward the dark outline, which is what made white and black
    /// pawns hard to tell apart. Going fully to the ends of the scale removes
    /// that ambiguity outright.
    private var fillColor: Color {
        switch pieceStyle {
        case .standard, .neo:
            return piece.color == .white ? .white : .black
        case .alpha:
            return piece.color == .white ? Color(white: 0.96) : Color(white: 0.06)
        case .merida:
            // Warm wood-toned set: ivory vs. walnut, like a traditional wooden board.
            return piece.color == .white
                ? Color(red: 0.97, green: 0.91, blue: 0.78)
                : Color(red: 0.32, green: 0.19, blue: 0.11)
        }
    }

    private var strokeColor: Color {
        switch pieceStyle {
        case .standard, .neo:
            return piece.color == .white ? .black : .white
        case .alpha:
            return piece.color == .white ? Color.black.opacity(0.85) : Color.white.opacity(0.85)
        case .merida:
            return piece.color == .white
                ? Color(red: 0.36, green: 0.22, blue: 0.10)
                : Color(red: 0.86, green: 0.72, blue: 0.48)
        }
    }

    /// How much larger the outline layer is drawn behind the fill layer, as a
    /// fraction of fontSize -- e.g. 0.12 means the outline glyph is rendered
    /// 12% bigger, so a consistent ring of the stroke color peeks out on all
    /// sides once the same-shape fill glyph is centered on top of it. This is
    /// a simpler, more robust "outlined text" technique than stacking several
    /// offset copies with a blurred shadow: two layers, no blur, no loop, so
    /// there's no room for small-glyph blending artifacts to muddy the color.
    private var outlineScale: CGFloat {
        switch pieceStyle {
        case .standard: return 1.14
        case .neo:       return 1.20   // bolder, modern flat look
        case .alpha:      return 1.08  // thin, elegant outline
        case .merida:     return 1.16  // traditional wooden-set weight
        }
    }

    var body: some View {
        ZStack {
            Text(piece.symbolForColor)
                .font(.system(size: fontSize * outlineScale))
                .foregroundColor(strokeColor)

            Text(piece.symbolForColor)
                .font(.system(size: fontSize))
                .foregroundColor(fillColor)
        }
        .shadow(color: .black.opacity(0.25), radius: fontSize * 0.03, x: 0, y: fontSize * 0.02)
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
    var pieceStyle: PieceStyle = .standard
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
                            ChessPieceGlyph(piece: chessPiece, fontSize: 48, pieceStyle: pieceStyle)
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
