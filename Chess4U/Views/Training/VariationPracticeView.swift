import SwiftUI

struct VariationPracticeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = VariationPracticeViewModel()
    let opening: ChessOpening?

    init(opening: ChessOpening? = nil) {
        self.opening = opening
    }

    var body: some View {
        VStack(spacing: 0) {
            // Variation info
            if let opening = opening ?? vm.currentOpening {
                variationHeader(opening)
            }

            // Board -- without the onChange the learner's moves never reached
            // the view model, so the feature was completely inert.
            ChessBoardView(vm: vm.boardVM, interactive: true)
                .padding()
                .onChange(of: vm.boardVM.game.moves.count) { _ in
                    if let lastMove = vm.boardVM.game.moves.last {
                        vm.handleMove(lastMove)
                    }
                }

            // Variation tree
            variationTreeSection

            // Move input area
            moveInputSection
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Variation Practice")
        .onAppear {
            vm.profile = appState.playerProfile
            if let opening = opening {
                vm.loadOpening(opening)
            } else {
                vm.loadRandomVariation()
            }
        }
    }

    func variationHeader(_ opening: ChessOpening) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(opening.name)
                    .font(.headline)
                Text(opening.eco + " · " + opening.color.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Depth: \(vm.currentDepth)/\(vm.targetDepth)")
                    .font(.caption)
                ProgressView(value: Double(vm.currentDepth), total: Double(vm.targetDepth))
                    .frame(width: 80)
                    .tint(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    var variationTreeSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.movePath.indices, id: \.self) { idx in
                    let move = vm.movePath[idx]
                    Text(move)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(idx == vm.currentDepth - 1 ?
                                   Color.blue.opacity(0.2) : Color(.systemGroupedBackground))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(idx == vm.currentDepth - 1 ? Color.blue : Color.clear)
                        )
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 44)
        .background(Color(.systemBackground))
    }

    var moveInputSection: some View {
        VStack(spacing: 12) {
            if let comment = vm.comment {
                Text(comment)
                    .font(.subheadline)
                    .foregroundColor(vm.isCorrect == true ? .green : vm.isCorrect == false ? .red : .secondary)
                    .padding(10)
                    .background((vm.isCorrect == true ? Color.green : vm.isCorrect == false ? Color.red : Color.gray).opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button {
                    vm.showHint()
                } label: {
                    Label("Hint", systemImage: "lightbulb")
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow.opacity(0.1))
                        .foregroundColor(.yellow)
                        .cornerRadius(10)
                }

                Button {
                    vm.skipVariation()
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.secondary)
                        .cornerRadius(10)
                }

                Button {
                    vm.restart()
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
}

// MARK: - Variation Practice ViewModel
@MainActor
class VariationPracticeViewModel: ObservableObject {
    @Published var boardVM = ChessBoardViewModel()
    @Published var currentOpening: ChessOpening?
    @Published var currentVariation: OpeningVariation?
    @Published var movePath: [String] = []
    @Published var currentDepth: Int = 0
    @Published var targetDepth: Int = 8
    @Published var comment: String? = nil
    @Published var isCorrect: Bool? = nil
    var profile: PlayerProfile?

    private var expectedMoves: [String] = []

    func loadOpening(_ opening: ChessOpening) {
        currentOpening = opening
        currentVariation = opening.variations.randomElement()
        expectedMoves = currentVariation?.moves ?? opening.moves
        targetDepth = expectedMoves.count
        restart()
    }

    func loadRandomVariation() {
        let opening = ChessOpening.openingLibrary.randomElement()!
        loadOpening(opening)
    }

    func restart() {
        boardVM = ChessBoardViewModel(profile: profile)
        movePath = []
        currentDepth = 0
        comment = nil
        isCorrect = nil
    }

    func showHint() {
        if currentDepth < expectedMoves.count {
            let nextMove = expectedMoves[currentDepth]
            comment = "💡 Hint: Play from \(nextMove.prefix(2)) to \(nextMove.dropFirst(2).prefix(2))"
        }
    }

    func skipVariation() {
        loadRandomVariation()
    }

    func handleMove(_ move: ChessMove) {
        guard currentDepth < expectedMoves.count else { return }
        // Ignore the scripted reply this view model plays itself -- variation
        // lines always start from the initial position, so the learner is White.
        guard move.piece.color == .white else { return }
        let expected = expectedMoves[currentDepth]
        let played = move.longAlgebraic

        if played == expected {
            movePath.append(move.notation.isEmpty ? played : move.notation)
            currentDepth += 1
            isCorrect = true
            comment = currentDepth >= expectedMoves.count ? "✅ Variation complete! Excellent!" : "Correct! Continue..."
            makeResponseMove()
        } else {
            isCorrect = false
            comment = "❌ \(move.notation.isEmpty ? played : move.notation) deviates from the book line. Board reset — try again!"
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 700_000_000)
                self?.boardVM.undoLastMove()
            }
        }
    }

    /// Actually plays the scripted reply on the board (previously this only
    /// incremented a counter, so the opponent never visibly moved).
    private func makeResponseMove() {
        guard currentDepth < expectedMoves.count else { return }
        let reply = expectedMoves[currentDepth]
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard let self = self else { return }
            guard self.currentDepth < self.expectedMoves.count else { return }
            if let move = ChessEngineService.shared.move(fromUCI: reply, board: self.boardVM.game.board) {
                self.boardVM.executeMove(move)
                self.movePath.append(move.notation.isEmpty ? move.longAlgebraic : move.notation)
                self.currentDepth += 1
            }
        }
    }
}
