import SwiftUI
import Combine

@MainActor
class GameAnalysisViewModel: ObservableObject {
    @Published var game: ChessGame?
    @Published var analysis: GameAnalysis?
    @Published var boardVM: ChessBoardViewModel = ChessBoardViewModel()
    @Published var currentMoveIndex: Int = 0
    @Published var isAnalyzing: Bool = false
    @Published var selectedMistake: MoveAnalysis? = nil
    @Published var showAudioExplanation: Bool = false

    private let aiCoach = AICoachService.shared
    private let audioCoach = AudioCoachService.shared
    var profile: PlayerProfile?
    var uiMode: UIMode = .study

    func analyzeGame(_ game: ChessGame) {
        self.game = game
        boardVM = ChessBoardViewModel(profile: profile)

        // Build a default profile so analysis always runs even when the user
        // hasn't completed onboarding yet — avoids the UI hanging on "Analyzing…".
        let effectiveProfile = profile ?? PlayerProfile(
            name: "Player", elo: 1000,
            preferredTimeControl: .rapid, playerType: .casual,
            mainOpeningsWhite: [], mainDefensesBlack: [],
            ratingTrend: .stable, weaknesses: [.tactics]
        )

        isAnalyzing = true
        let aiCoach = self.aiCoach  // capture before leaving MainActor context
        aiCoach.uiMode = self.uiMode

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = aiCoach.analyzeGame(game, profile: effectiveProfile)
            DispatchQueue.main.async {
                self?.analysis = result
                self?.isAnalyzing = false
            }
        }
    }

    func goToMove(_ index: Int) {
        guard let game = game else { return }
        currentMoveIndex = min(max(0, index), game.moves.count)
        reconstructBoard(upToMove: currentMoveIndex)
    }

    func nextMove() { goToMove(currentMoveIndex + 1) }
    func previousMove() { goToMove(currentMoveIndex - 1) }
    func firstMove() { goToMove(0) }
    func lastMove() { goToMove(game?.moves.count ?? 0) }

    private func reconstructBoard(upToMove index: Int) {
        boardVM = ChessBoardViewModel(profile: profile)
        guard let game = game else { return }
        for i in 0..<min(index, game.moves.count) {
            boardVM.game.makeMove(game.moves[i])
        }
        if index > 0 && index <= game.moves.count {
            boardVM.lastMove = game.moves[index - 1]
        }
    }

    func speakAnalysis() {
        guard let analysis = analysis else { return }
        audioCoach.speak(analysis.summary)
        if let firstMistake = analysis.criticalMistakes.first {
            audioCoach.speakMoveAnalysis(quality: firstMistake.quality, explanation: firstMistake.explanation)
        }
    }

    var evaluationGraphData: [Double] {
        analysis?.evaluationHistory ?? []
    }

    var moveQualityColor: Color {
        guard let move = selectedMistake else { return .gray }
        switch move.quality {
        case .best, .good: return .green
        case .acceptable:  return .blue
        case .inaccuracy:  return .yellow
        case .mistake:     return .orange
        case .blunder:     return .red
        }
    }
}
