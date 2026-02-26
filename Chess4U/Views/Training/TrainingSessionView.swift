import SwiftUI

struct TrainingSessionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = TrainingViewModel()
    @Environment(\.presentationMode) var presentationMode
    let trainingType: TrainingType

    @State private var showLessonSheet: Bool = false
    @State private var showBlunderSheet: Bool = false
    @State private var phase: SessionPhase = .lesson

    enum SessionPhase {
        case lesson, warmup, mainSession, complete
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            switch phase {
            case .lesson:
                if let lesson = vm.session?.conceptLesson {
                    ConceptLessonView(lesson: lesson) {
                        withAnimation { phase = .warmup }
                    }
                } else {
                    warmupView
                }
            case .warmup:
                warmupView
            case .mainSession:
                mainPuzzleView
            case .complete:
                SessionCompleteView(session: vm.session, score: vm.sessionScore) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .navigationTitle(trainingType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let session = vm.session {
                    Text("\(session.puzzlesSolved)/\(session.warmupPuzzles.count + session.mainPuzzles.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            vm.profile = appState.playerProfile
            vm.startSession(type: trainingType)
            if vm.session?.conceptLesson == nil {
                phase = .warmup
            }
        }
        .onChange(of: vm.isSessionComplete) { complete in
            if complete {
                if let session = vm.session {
                    appState.recordSessionCompletion(session: session)
                }
                withAnimation { phase = .complete }
            }
        }
        .onChange(of: vm.session?.currentPuzzleIndex) { idx in
            guard let session = vm.session else { return }
            if idx ?? 0 >= session.warmupPuzzles.count && phase == .warmup {
                withAnimation { phase = .mainSession }
            }
        }
    }

    var warmupView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Label("Warm-Up: \(vm.session?.warmupPuzzles.count ?? 5) Puzzles", systemImage: "flame")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    Spacer()
                }

                ProgressView(value: vm.currentPuzzleProgress)
                    .tint(.orange)
            }
            .padding()
            .background(Color(.systemBackground))

            puzzleContent
        }
    }

    var mainPuzzleView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    Label("Main Session", systemImage: trainingType.icon)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Spacer()
                    Text("Score: \(vm.sessionScore)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                ProgressView(value: vm.currentPuzzleProgress)
                    .tint(.blue)
            }
            .padding()
            .background(Color(.systemBackground))

            puzzleContent
        }
    }

    var puzzleContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Puzzle info
                if let puzzle = vm.currentPuzzle {
                    PuzzleInfoCard(puzzle: puzzle)
                }

                // Chess Board
                ChessBoardView(vm: vm.boardVM, interactive: true)
                    .padding(.horizontal)
                    .onChange(of: vm.boardVM.game.moves.count) { _ in
                        if let lastMove = vm.boardVM.game.moves.last {
                            vm.handlePlayerMove(lastMove)
                        }
                    }

                // Status
                PuzzleStatusView(state: vm.puzzleState, comment: vm.coachComment)

                // Blunder Check Questions
                if vm.puzzleState == .waitingForMove {
                    BlunderCheckView(questions: vm.blunderCheckQuestions)
                }

                // Buttons
                HStack(spacing: 12) {
                    Button {
                        vm.requestHint()
                    } label: {
                        Label("Hint", systemImage: "lightbulb")
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.yellow.opacity(0.15))
                            .foregroundColor(.yellow)
                            .cornerRadius(10)
                    }

                    Button {
                        // Show solution
                        vm.puzzleState = .showingSolution
                    } label: {
                        Label("Solution", systemImage: "eye")
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)

                if !vm.hintText.isEmpty {
                    Text(vm.hintText)
                        .font(.subheadline)
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                // Coach Insight
                if let insight = vm.boardVM.coachInsight {
                    CoachInsightView(insight: insight)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Concept Lesson View
struct ConceptLessonView: View {
    let lesson: ConceptLesson
    let onContinue: () -> Void
    @StateObject private var audioCoach = AudioCoachService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Today's Lesson")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(lesson.title)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    Button {
                        audioCoach.speakLesson(lesson)
                    } label: {
                        Image(systemName: audioCoach.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(16)

                lessonSection("📖 Concept", lesson.concept)
                lessonSection("💡 Explanation", lesson.explanation)
                lessonSection("🎯 Example", lesson.example)
                lessonSection("🔑 Key Idea", lesson.keyIdea)
                lessonSection("⚠️ Common Mistake", lesson.commonMistake)
                lessonSection("♟ How Strong Players Use It", lesson.howStrongPlayersUseIt)

                Button {
                    audioCoach.stop()
                    onContinue()
                } label: {
                    Text("Continue to Practice")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .font(.headline)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    func lessonSection(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Puzzle Info Card
struct PuzzleInfoCard: View {
    let puzzle: ChessPuzzle

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(puzzle.title)
                    .font(.headline)
                HStack {
                    Text(puzzle.theme.rawValue)
                        .font(.caption)
                        .padding(4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    Text(puzzle.difficulty.rawValue)
                        .font(.caption)
                        .padding(4)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                    Text("\(puzzle.playerToMove.rawValue.capitalized) to move")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(puzzle.theme.icon)
                .font(.title)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .padding(.horizontal)
    }
}

// MARK: - Puzzle Status View
struct PuzzleStatusView: View {
    let state: PuzzleState
    let comment: String

    var body: some View {
        if !comment.isEmpty {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text(comment)
                    .font(.subheadline)
                    .foregroundColor(statusColor)
                Spacer()
            }
            .padding()
            .background(statusColor.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(), value: comment)
        }
    }

    var statusIcon: String {
        switch state {
        case .solved: return "checkmark.circle.fill"
        case .incorrect: return "xmark.circle.fill"
        case .correct: return "checkmark"
        default: return "info.circle"
        }
    }

    var statusColor: Color {
        switch state {
        case .solved: return .green
        case .incorrect: return .red
        case .correct: return .blue
        default: return .secondary
        }
    }
}

// MARK: - Blunder Check View
struct BlunderCheckView: View {
    let questions: [String]
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.red)
                    Text("Blunder Check — Before You Move")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(questions.prefix(4), id: \.self) { q in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundColor(.red)
                            Text(q)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2)))
        .padding(.horizontal)
    }
}

// MARK: - Coach Insight View
struct CoachInsightView: View {
    let insight: CoachInsight

    var insightColor: Color {
        switch insight.moveQuality {
        case .best, .good: return .green
        case .acceptable: return .blue
        case .inaccuracy: return .yellow
        case .mistake: return .orange
        case .blunder: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.fill.questionmark")
                    .foregroundColor(.purple)
                Text("Coach Insight")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(insight.qualityIcon + " " + insight.moveQuality.rawValue)
                    .font(.caption)
                    .padding(6)
                    .background(insightColor.opacity(0.15))
                    .foregroundColor(insightColor)
                    .cornerRadius(8)
            }

            Text(insight.strategicIdea)
                .font(.body)

            if let tactical = insight.tacticalReason {
                Text("⚡ " + tactical)
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Text("🏆 " + insight.tournamentAdvice)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
    }
}

// MARK: - Session Complete View
struct SessionCompleteView: View {
    let session: TrainingSession?
    let score: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Text("🏆")
                    .font(.system(size: 72))
                Text("Session Complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Great work! Keep up the momentum.")
                    .foregroundColor(.secondary)
            }

            // Stats
            VStack(spacing: 16) {
                StatRow(label: "Score", value: "\(score)")
                if let session = session {
                    StatRow(label: "Puzzles Solved", value: "\(session.puzzlesSolved)")
                    StatRow(label: "Accuracy",
                            value: "\(Int(session.puzzleAccuracy))%")
                    if let duration = session.duration {
                        StatRow(label: "Time", value: "\(Int(duration / 60)) min")
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)

            Spacer()

            Button(action: onDismiss) {
                Text("Back to Training")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .padding()
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}
