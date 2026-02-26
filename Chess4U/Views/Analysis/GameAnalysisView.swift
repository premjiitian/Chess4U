import SwiftUI

struct GameAnalysisView: View {
    @EnvironmentObject var appState: AppState
    let game: ChessGame
    @StateObject private var vm = GameAnalysisViewModel()
    @StateObject private var audioCoach = AudioCoachService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if vm.isAnalyzing {
                    analyzingView
                } else if let analysis = vm.analysis {
                    analysisContent(analysis)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            vm.profile = appState.playerProfile
            vm.analyzeGame(game)
        }
    }

    var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
            Text("Analyzing your game...")
                .font(.headline)
            Text("This may take a moment")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    func analysisContent(_ analysis: GameAnalysis) -> some View {
        VStack(spacing: 16) {
            // Board replay
            VStack(spacing: 0) {
                ChessBoardView(vm: vm.boardVM, interactive: false)
                    .padding(8)

                // Playback controls
                HStack(spacing: 24) {
                    Button { vm.firstMove() } label: {
                        Image(systemName: "backward.end.fill")
                    }
                    Button { vm.previousMove() } label: {
                        Image(systemName: "backward.fill")
                    }
                    Text("Move \(vm.currentMoveIndex)/\(game.moves.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button { vm.nextMove() } label: {
                        Image(systemName: "forward.fill")
                    }
                    Button { vm.lastMove() } label: {
                        Image(systemName: "forward.end.fill")
                    }
                }
                .font(.title3)
                .padding()
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)

            // Game Summary
            summaryCard(analysis)

            // Evaluation Graph
            EvaluationGraphView(data: analysis.evaluationHistory)
                .frame(height: 100)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)

            // Critical Mistakes
            if !analysis.criticalMistakes.isEmpty {
                mistakesCard(analysis.criticalMistakes)
            }

            // Improvement Advice
            improvementCard(analysis.improvementAdvice)
        }
    }

    func summaryCard(_ analysis: GameAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Game Summary", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                Spacer()
                Button {
                    vm.speakAnalysis()
                } label: {
                    Image(systemName: audioCoach.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(.blue)
                }
            }

            Text(analysis.summary)
                .font(.body)
                .foregroundColor(.secondary)

            HStack {
                accuracyBadge("Accuracy", "\(Int(analysis.accuracy))%",
                               analysis.accuracy > 75 ? .green : analysis.accuracy > 50 ? .orange : .red)
                Spacer()
                accuracyBadge("Mistakes", "\(analysis.criticalMistakes.count)", .red)
                Spacer()
                accuracyBadge("Best Moves", "\(analysis.goodMoves.count)", .green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    func accuracyBadge(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
    }

    func mistakesCard(_ mistakes: [MoveAnalysis]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Critical Moments", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundColor(.orange)

            ForEach(mistakes.prefix(5)) { mistake in
                Button {
                    vm.selectedMistake = mistake
                    vm.goToMove(mistake.moveNumber)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Move \(mistake.moveNumber): \(mistake.move.notation.isEmpty ? mistake.move.longAlgebraic : mistake.move.notation)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text(mistake.explanation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(mistake.quality.icon)
                            .font(.title3)
                    }
                    .padding(10)
                    .background(vm.selectedMistake?.id == mistake.id ?
                               Color.orange.opacity(0.15) : Color(.systemGroupedBackground))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    func improvementCard(_ advice: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Improvement Advice", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundColor(.yellow)

            ForEach(advice, id: \.self) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .padding(.top, 2)
                    Text(tip)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Evaluation Graph
struct EvaluationGraphView: View {
    let data: [Double]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let midY = height / 2
            let clampedData = data.map { max(-5, min(5, $0)) }

            ZStack {
                // Center line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: width, y: midY))
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                // White advantage area
                if clampedData.count > 1 {
                    Path { path in
                        let step = width / CGFloat(clampedData.count - 1)
                        path.move(to: CGPoint(x: 0, y: midY))
                        for (i, val) in clampedData.enumerated() {
                            let x = CGFloat(i) * step
                            let y = midY - CGFloat(val) * midY / 5.0
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: width, y: midY))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [.blue.opacity(0.3), .clear],
                                         startPoint: .top, endPoint: .bottom))

                    // Eval line
                    Path { path in
                        let step = width / CGFloat(clampedData.count - 1)
                        for (i, val) in clampedData.enumerated() {
                            let x = CGFloat(i) * step
                            let y = midY - CGFloat(val) * midY / 5.0
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
            }
        }
    }
}
