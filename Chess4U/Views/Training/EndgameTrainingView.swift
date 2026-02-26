import SwiftUI

struct EndgameTrainingView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCategory: EndgameCategory = .kingPawn
    @StateObject private var boardVM = ChessBoardViewModel()

    enum EndgameCategory: String, CaseIterable {
        case kingPawn = "King & Pawn"
        case rookEndgame = "Rook Endgame"
        case queenEndgame = "Queen Endgame"
        case pieceTechnique = "Piece Technique"

        var icon: String {
            switch self {
            case .kingPawn: return "♟"
            case .rookEndgame: return "♜"
            case .queenEndgame: return "♛"
            case .pieceTechnique: return "♞"
            }
        }

        var description: String {
            switch self {
            case .kingPawn: return "Opposition, key squares, rule of the square"
            case .rookEndgame: return "Philidor, Lucena, active rook"
            case .queenEndgame: return "Queen vs pawn, fortress positions"
            case .pieceTechnique: return "Bishop pairs, knight vs bishop"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(EndgameCategory.allCases, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            VStack(spacing: 4) {
                                Text(cat.icon)
                                    .font(.title2)
                                Text(cat.rawValue)
                                    .font(.caption)
                            }
                            .padding(10)
                            .background(selectedCategory == cat ? Color.green.opacity(0.2) : Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedCategory == cat ? Color.green : Color.gray.opacity(0.2))
                            )
                        }
                        .foregroundColor(selectedCategory == cat ? .green : .primary)
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))

            ScrollView {
                VStack(spacing: 16) {
                    // Theory card
                    theoryCard

                    // Practice positions
                    practiceSection

                    // Technique drills
                    techniqueSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("Endgame Training")
    }

    var theoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "books.vertical.fill")
                    .foregroundColor(.green)
                Text(selectedCategory.rawValue + " — Theory")
                    .font(.headline)
            }

            Text(selectedCategory.description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let profile = appState.playerProfile {
                let tips = endgameTips(for: selectedCategory, band: profile.band)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                                .padding(.top, 2)
                            Text(tip)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    var practiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text("Practice Positions")
                    .font(.headline)
            }

            let puzzles = endgamePuzzles(for: selectedCategory)
            ForEach(puzzles) { puzzle in
                NavigationLink(destination: EndgamePuzzleView(puzzle: puzzle)) {
                    HStack {
                        Text(puzzle.theme.icon)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(puzzle.title)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                            Text(puzzle.difficulty.rawValue + " · \(puzzle.solution.count) moves")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    var techniqueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flag.checkered")
                    .foregroundColor(.green)
                Text("Technique Drills")
                    .font(.headline)
            }

            Text("Practice converting specific endgame positions against the engine.")
                .font(.caption)
                .foregroundColor(.secondary)

            NavigationLink(destination: TrainingSessionView(trainingType: .endgame)) {
                Label("Start Endgame Session", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    func endgameTips(for category: EndgameCategory, band: PlayerBand) -> [String] {
        switch category {
        case .kingPawn:
            switch band {
            case .bandA, .bandB:
                return [
                    "Activate your king immediately when queens leave the board",
                    "Use opposition to outmaneuver the enemy king",
                    "Remember the rule of the square for passed pawns"
                ]
            default:
                return [
                    "Master key squares for every pawn position",
                    "Triangulation is the key to zugzwang",
                    "Pawn breakthrough patterns win many endgames"
                ]
            }
        case .rookEndgame:
            return [
                "Place rooks behind passed pawns — yours or theirs",
                "The Philidor position draws — rook on the 6th rank",
                "The Lucena position wins — building a bridge",
                "Cut off the enemy king with your rook"
            ]
        case .queenEndgame:
            return [
                "Queen wins against almost all pawns except rook or bishop pawns on the 7th",
                "Use forks and checks to control the enemy king",
                "Watch out for fortress positions"
            ]
        case .pieceTechnique:
            return [
                "The bishop pair is powerful in open positions",
                "A knight needs a strong outpost to be effective in endgames",
                "Bishops of opposite color often lead to draws"
            ]
        }
    }

    func endgamePuzzles(for category: EndgameCategory) -> [ChessPuzzle] {
        ChessPuzzle.puzzleDatabase.filter { puzzle in
            switch category {
            case .kingPawn, .pieceTechnique:
                return puzzle.theme == .endgameTechnique || puzzle.theme == .passedPawn
            case .rookEndgame:
                return puzzle.theme == .endgameTechnique
            case .queenEndgame:
                return puzzle.theme == .backRankMate || puzzle.theme == .mateInOne
            }
        }
    }
}

// MARK: - Endgame Puzzle View
struct EndgamePuzzleView: View {
    let puzzle: ChessPuzzle
    @StateObject private var vm = TrainingViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack {
            ChessBoardView(vm: vm.boardVM, interactive: true)
                .padding()

            VStack(alignment: .leading, spacing: 12) {
                Text(puzzle.title)
                    .font(.headline)
                Text(puzzle.explanation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal)

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Endgame Practice")
        .onAppear {
            vm.profile = appState.playerProfile
            vm.loadPuzzle(puzzle)
        }
    }
}
