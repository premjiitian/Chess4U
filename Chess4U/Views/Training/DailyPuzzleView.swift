import SwiftUI

// MARK: - Daily Puzzle View
/// Shows the Puzzle of the Day with a timer, streak counter, and celebration
/// on correct solution. Designed as a standalone sheet or a tab destination.
struct DailyPuzzleView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var service = DailyPuzzleService.shared
    @StateObject private var vm = TrainingViewModel()
    @State private var startTime: Date = Date()
    @State private var showCelebration: Bool = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    if service.isCompleted {
                        completedView
                    } else if let puzzle = service.todaysPuzzle {
                        puzzleContent(puzzle)
                    } else {
                        Text("No puzzle available today. Check back tomorrow!")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Daily Puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(celebrationOverlay)
            .onAppear(perform: setupPuzzle)
            .onDisappear { stopTimer() }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Sub-views

    var headerSection: some View {
        HStack {
            // Today's date
            VStack(alignment: .leading, spacing: 2) {
                Text(Date(), format: .dateTime.weekday(.wide))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(Date(), format: .dateTime.month().day())
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Spacer()
            // Streak display
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(service.streak)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Text("day streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    func puzzleContent(_ puzzle: ChessPuzzle) -> some View {
        VStack(spacing: 16) {
            // Puzzle info card
            puzzleInfoCard(puzzle)

            // Board
            VStack(spacing: 8) {
                ChessBoardView(vm: vm.boardVM, interactive: true)
                    .padding(.horizontal, 8)
                    .onChange(of: vm.boardVM.game.moves.count) { _ in
                        if let lastMove = vm.boardVM.game.moves.last {
                            vm.handlePlayerMove(lastMove)
                        }
                    }

                // Timer display
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text(formatTime(elapsedTime))
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.secondary)
                    Spacer()
                    if let best = service.bestTime {
                        Text("Best: \(formatTime(best))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(16)

            // State feedback
            if !vm.coachComment.isEmpty {
                feedbackCard(vm.coachComment,
                             color: vm.puzzleState == .incorrect ? .orange : .green,
                             icon: vm.puzzleState == .incorrect ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
            }

            // Hint button
            if vm.puzzleState == .waitingForMove {
                Button {
                    vm.requestHint()
                } label: {
                    Label("Show Hint", systemImage: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow.opacity(0.12))
                        .cornerRadius(12)
                }

                if !vm.hintText.isEmpty {
                    feedbackCard(vm.hintText, color: .yellow, icon: "lightbulb.fill")
                }
            }
        }
    }

    func puzzleInfoCard(_ puzzle: ChessPuzzle) -> some View {
        HStack(spacing: 12) {
            Text(puzzle.theme.icon)
                .font(.largeTitle)
                .frame(width: 48, height: 48)
                .background(Color.blue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(puzzle.title)
                    .font(.headline)
                Text(puzzle.theme.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    difficultyBadge(puzzle.difficulty)
                    Text("Rating \(puzzle.rating)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Today's Puzzle Complete!")
                .font(.title2)
                .fontWeight(.bold)

            if let best = service.bestTime {
                Text("Best time: \(formatTime(best))")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Text("Come back tomorrow for a new daily puzzle.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Show yesterday's solution
            if let puzzle = service.todaysPuzzle {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Solution", systemImage: "key.fill")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text(puzzle.explanation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.08))
                .cornerRadius(12)
            }

            // The daily puzzle is deliberately one-per-day (like chess.com/Lichess),
            // but that shouldn't be a dead end -- give people who want to keep
            // solving somewhere to go rather than just "come back tomorrow".
            NavigationLink(destination: TrainingSessionView(trainingType: .tactics)) {
                Label("Practice More Puzzles", systemImage: "puzzlepiece.extension.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    var celebrationOverlay: some View {
        Group {
            if showCelebration {
                ConfettiOverlay(
                    onDismiss: { showCelebration = false },
                    isKidsMode: appState.settings.uiMode == .kids,
                    xpEarned: appState.settings.uiMode == .kids ? 100 : 50
                )
            }
        }
    }

    // MARK: - Helpers

    func feedbackCard(_ text: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    func difficultyBadge(_ difficulty: PuzzleDifficulty) -> some View {
        let color: Color
        switch difficulty {
        case .beginner: color = .green
        case .easy:     color = .mint
        case .medium:   color = .blue
        case .hard:     color = .orange
        case .expert:   color = .red
        }
        return Text(difficulty.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }

    func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Setup

    private func setupPuzzle() {
        guard let puzzle = service.todaysPuzzle, !service.isCompleted else { return }
        vm.profile = appState.playerProfile
        vm.loadPuzzle(puzzle)
        startTime = Date()
        startTimer()

        // Observe puzzle solved
        vm.$puzzleState
            .dropFirst()
            .filter { $0 == .solved }
            .sink { [weak service] _ in
                let elapsed = Date().timeIntervalSince(self.startTime)
                service?.markCompleted(timeSpent: elapsed)
                SoundService.shared.playPuzzleSolved()
                HapticService.shared.promotion()
                withAnimation { self.showCelebration = true }
                self.stopTimer()
            }
            .store(in: &cancellables)
    }

    @State private var cancellables = Set<AnyCancellable>()

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(startTime)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Confetti Overlay
/// Star-burst confetti animation shown on puzzle completion.
/// In Kids Mode (uiMode == .kids) it adds XP reward display and larger celebratory text.
struct ConfettiOverlay: View {
    let onDismiss: () -> Void
    var isKidsMode: Bool = false
    var xpEarned: Int = 50

    @State private var particles: [ConfettiParticle] = []
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.5

    var body: some View {
        ZStack {
            Color.black.opacity(isKidsMode ? 0.55 : 0.01)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .position(p.position)
                    .opacity(opacity)
            }

            VStack(spacing: isKidsMode ? 20 : 16) {
                Text(isKidsMode ? "🌟🏆🌟" : "🎉")
                    .font(.system(size: isKidsMode ? 88 : 72))
                    .scaleEffect(scale)

                Text(isKidsMode ? "AMAZING!" : "Puzzle Solved!")
                    .font(isKidsMode ? .system(size: 36, weight: .black) : .title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(radius: 4)

                if isKidsMode {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("+\(xpEarned) XP")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(20)
                }

                Text("Tap to continue")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .onTapGesture { onDismiss() }
        }
        .onAppear {
            spawnParticles()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
            }
            withAnimation(.easeOut(duration: 2.5).delay(1.5)) {
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                onDismiss()
            }
        }
    }

    private func spawnParticles() {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height
        let count = isKidsMode ? 120 : 80
        particles = (0..<count).map { _ in
            ConfettiParticle(
                color: colors.randomElement()!,
                size: CGFloat.random(in: isKidsMode ? 8...18 : 6...14),
                position: CGPoint(x: CGFloat.random(in: 0...screenW),
                                  y: CGFloat.random(in: 0...screenH))
            )
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let position: CGPoint
}

import Combine
