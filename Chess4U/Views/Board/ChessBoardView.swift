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
/// Renders a chess piece as real vector artwork -- each piece type is a
/// hand-authored SwiftUI `Shape` (see `ChessPieceShape` below), filled and
/// stroked like a traditional Staunton set, instead of a Unicode font glyph.
/// The proportions/palette were checked against a chess.com reference
/// screenshot (cream/steel-blue board, ivory vs. charcoal pieces) via a
/// preview before being ported into real code here.
struct ChessPieceGlyph: View {
    let piece: ChessPiece
    let fontSize: CGFloat
    /// Which of the four named piece sets (Settings > Piece Style) to render.
    /// All four styles share the same vector shapes; only palette and stroke
    /// weight change between them.
    var pieceStyle: PieceStyle = .standard

    /// Deliberately at the extremes (pure white / pure black) for .standard
    /// and .neo so there's no ambiguity between white and black pieces even
    /// at small (pawn) sizes.
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

    /// Stroke weight as a fraction of fontSize -- mirrors the old per-style
    /// outline weighting, now drawn as a real vector stroke around the piece
    /// silhouette instead of a larger duplicate glyph placed behind it.
    private var strokeWidth: CGFloat {
        switch pieceStyle {
        case .standard: return fontSize * 0.05
        case .neo:       return fontSize * 0.065  // bolder, modern flat look
        case .alpha:     return fontSize * 0.035  // thin, elegant outline
        case .merida:    return fontSize * 0.055  // traditional wooden-set weight
        }
    }

    var body: some View {
        ZStack {
            ChessPieceShape(type: piece.type)
                .fill(fillColor)
                .overlay(
                    ChessPieceShape(type: piece.type)
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )

            // Small engraved details drawn as separate thin shapes rather
            // than baked into the fill/stroke silhouette -- the bishop's
            // mitre slit and the knight's eye.
            switch piece.type {
            case .bishop:
                Capsule()
                    .fill(strokeColor.opacity(0.7))
                    .frame(width: fontSize * 0.23, height: fontSize * 0.035)
                    .offset(y: -fontSize * 0.11)
            case .knight:
                Circle()
                    .fill(strokeColor.opacity(0.55))
                    .frame(width: fontSize * 0.05, height: fontSize * 0.05)
                    .offset(x: fontSize * 0.09, y: -fontSize * 0.24)
            default:
                EmptyView()
            }
        }
        .frame(width: fontSize, height: fontSize)
        .shadow(color: .black.opacity(0.25), radius: fontSize * 0.03, x: 0, y: fontSize * 0.02)
    }
}

/// A single piece silhouette, normalized to a 45x45 coordinate space (the
/// convention most chess piece sets use) and scaled to fit whatever square
/// `rect` it's given. Proportions follow a traditional Staunton set: king
/// tallest with a cross finial, queen with a five-point crown, bishop with a
/// mitre slit, knight a hook-profile horse head, rook crenellated, pawn a
/// simple ball-and-body.
struct ChessPieceShape: Shape {
    let type: PieceType

    func path(in rect: CGRect) -> Path {
        switch type {
        case .pawn:   return pawnPath(in: rect)
        case .rook:   return rookPath(in: rect)
        case .knight: return knightPath(in: rect)
        case .bishop: return bishopPath(in: rect)
        case .queen:  return queenPath(in: rect)
        case .king:   return kingPath(in: rect)
        }
    }

    private func scale(_ rect: CGRect) -> (CGFloat, (CGFloat, CGFloat) -> CGPoint) {
        let s = rect.width / 45
        let pt: (CGFloat, CGFloat) -> CGPoint = { x, y in
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        return (s, pt)
    }

    private func pawnPath(in rect: CGRect) -> Path {
        let (s, pt) = scale(rect)
        var p = Path()
        p.addEllipse(in: CGRect(x: rect.minX + (22.5 - 6.3) * s, y: rect.minY + (11 - 6.3) * s,
                                 width: 12.6 * s, height: 12.6 * s))
        p.move(to: pt(16, 19))
        p.addQuadCurve(to: pt(29, 19), control: pt(22.5, 15))
        p.addLine(to: pt(32, 30))
        p.addQuadCurve(to: pt(13, 30), control: pt(22.5, 34.5))
        p.closeSubpath()
        p.addRoundedRect(in: CGRect(x: rect.minX + 10 * s, y: rect.minY + 33.5 * s, width: 25 * s, height: 6 * s),
                          cornerSize: CGSize(width: 2 * s, height: 2 * s))
        return p
    }

    private func rookPath(in rect: CGRect) -> Path {
        let (s, pt) = scale(rect)
        var p = Path()
        p.addRect(CGRect(x: rect.minX + 10.5 * s, y: rect.minY + 9 * s, width: 4.2 * s, height: 5.5 * s))
        p.addRect(CGRect(x: rect.minX + 20.4 * s, y: rect.minY + 9 * s, width: 4.2 * s, height: 5.5 * s))
        p.addRect(CGRect(x: rect.minX + 30.3 * s, y: rect.minY + 9 * s, width: 4.2 * s, height: 5.5 * s))
        p.addRect(CGRect(x: rect.minX + 9.5 * s, y: rect.minY + 14.5 * s, width: 26 * s, height: 4 * s))
        p.move(to: pt(12.5, 18.5))
        p.addLine(to: pt(32.5, 18.5))
        p.addLine(to: pt(29.5, 31))
        p.addLine(to: pt(15.5, 31))
        p.closeSubpath()
        p.addRoundedRect(in: CGRect(x: rect.minX + 10 * s, y: rect.minY + 33.5 * s, width: 25 * s, height: 6 * s),
                          cornerSize: CGSize(width: 2 * s, height: 2 * s))
        return p
    }

    private func knightPath(in rect: CGRect) -> Path {
        let (_, pt) = scale(rect)
        var p = Path()
        p.move(to: pt(31, 33.5))
        p.addLine(to: pt(12.5, 33.5))
        p.addQuadCurve(to: pt(10.5, 31.5), control: pt(10.5, 33.5))
        p.addLine(to: pt(10.5, 30))
        p.addQuadCurve(to: pt(12.5, 28), control: pt(10.5, 28))
        p.addLine(to: pt(18, 28))
        p.addCurve(to: pt(17.2, 15.6), control1: pt(15.4, 24.4), control2: pt(14.7, 20))
        p.addCurve(to: pt(26.9, 8.8), control1: pt(19.4, 11.7), control2: pt(23.2, 8.8))
        p.addCurve(to: pt(31.7, 13.2), control1: pt(29.7, 8.8), control2: pt(31.7, 10.7))
        p.addCurve(to: pt(29.1, 16.1), control1: pt(31.7, 14.9), control2: pt(30.6, 16.1))
        p.addCurve(to: pt(27.3, 14.4), control1: pt(28.1, 16.1), control2: pt(27.3, 15.4))
        p.addCurve(to: pt(25.2, 17.7), control1: pt(25.5, 14.2), control2: pt(24.3, 16.0))
        p.addLine(to: pt(31.4, 21.4))
        p.addCurve(to: pt(35.0, 27.5), control1: pt(33.6, 22.7), control2: pt(35.0, 25.0))
        p.addLine(to: pt(35.0, 31.2))
        p.addQuadCurve(to: pt(33.0, 33.2), control: pt(35.0, 33.2))
        p.closeSubpath()
        return p
    }

    private func bishopPath(in rect: CGRect) -> Path {
        let (s, pt) = scale(rect)
        var p = Path()
        p.addEllipse(in: CGRect(x: rect.minX + (22.5 - 2.3) * s, y: rect.minY + (5.5 - 2.3) * s,
                                 width: 4.6 * s, height: 4.6 * s))
        p.addRect(CGRect(x: rect.minX + 21.7 * s, y: rect.minY + 7.6 * s, width: 1.6 * s, height: 2.6 * s))
        p.addEllipse(in: CGRect(x: rect.minX + (22.5 - 6.4) * s, y: rect.minY + (15 - 6.4) * s,
                                 width: 12.8 * s, height: 12.8 * s))
        p.move(to: pt(16, 20.5))
        p.addQuadCurve(to: pt(29, 20.5), control: pt(22.5, 17))
        p.addLine(to: pt(32, 31))
        p.addQuadCurve(to: pt(13, 31), control: pt(22.5, 35.2))
        p.closeSubpath()
        p.addRoundedRect(in: CGRect(x: rect.minX + 10 * s, y: rect.minY + 33.5 * s, width: 25 * s, height: 6 * s),
                          cornerSize: CGSize(width: 2 * s, height: 2 * s))
        return p
    }

    private func queenPath(in rect: CGRect) -> Path {
        let (s, pt) = scale(rect)
        var p = Path()
        let crownPoints: [(CGFloat, CGFloat, CGFloat)] = [
            (9.5, 10.5, 2.3), (16.3, 6.2, 2.3), (22.5, 4.3, 2.5), (28.7, 6.2, 2.3), (35.5, 10.5, 2.3)
        ]
        for (cx, cy, r) in crownPoints {
            p.addEllipse(in: CGRect(x: rect.minX + (cx - r) * s, y: rect.minY + (cy - r) * s,
                                     width: 2 * r * s, height: 2 * r * s))
        }
        p.move(to: pt(10.5, 12.5))
        p.addLine(to: pt(34.5, 12.5))
        p.addLine(to: pt(31.5, 22.5))
        p.addQuadCurve(to: pt(13.5, 22.5), control: pt(22.5, 26.5))
        p.closeSubpath()
        p.move(to: pt(14, 22.8))
        p.addQuadCurve(to: pt(31, 22.8), control: pt(22.5, 34.5))
        p.addLine(to: pt(33.2, 34.5))
        p.addQuadCurve(to: pt(11.8, 34.5), control: pt(22.5, 39.5))
        p.closeSubpath()
        p.addRoundedRect(in: CGRect(x: rect.minX + 9.5 * s, y: rect.minY + 38 * s, width: 26 * s, height: 5.5 * s),
                          cornerSize: CGSize(width: 2 * s, height: 2 * s))
        return p
    }

    private func kingPath(in rect: CGRect) -> Path {
        let (s, pt) = scale(rect)
        var p = Path()
        // Cross finial, drawn as two thin rounded bars rather than a stroked line.
        p.addRoundedRect(in: CGRect(x: rect.minX + (22.5 - 1.3) * s, y: rect.minY + 1.5 * s,
                                     width: 2.6 * s, height: 7 * s), cornerSize: CGSize(width: 1.3 * s, height: 1.3 * s))
        p.addRoundedRect(in: CGRect(x: rect.minX + 19 * s, y: rect.minY + (4.7 - 1.3) * s,
                                     width: 7 * s, height: 2.6 * s), cornerSize: CGSize(width: 1.3 * s, height: 1.3 * s))
        p.move(to: pt(13.5, 11.5))
        p.addLine(to: pt(31.5, 11.5))
        p.addLine(to: pt(28.7, 19.5))
        p.addQuadCurve(to: pt(16.3, 19.5), control: pt(22.5, 23.3))
        p.closeSubpath()
        p.move(to: pt(13, 20))
        p.addQuadCurve(to: pt(32, 20), control: pt(22.5, 34.5))
        p.addLine(to: pt(34.2, 34.5))
        p.addQuadCurve(to: pt(10.8, 34.5), control: pt(22.5, 40))
        p.closeSubpath()
        p.addRoundedRect(in: CGRect(x: rect.minX + 8.8 * s, y: rect.minY + 38 * s, width: 27.4 * s, height: 5.5 * s),
                          cornerSize: CGSize(width: 2 * s, height: 2 * s))
        return p
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
