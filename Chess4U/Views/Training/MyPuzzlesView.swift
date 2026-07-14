import SwiftUI

// MARK: - My Puzzles View
/// Browses the player's personal puzzle collection: mistakes/inaccuracies/
/// blunders auto-detected from synced chess.com/Lichess games, plus any
/// positions manually bookmarked while reviewing a game in GameAnalysisView.
struct MyPuzzlesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    @State private var puzzles: [ChessPuzzle] = []

    private let persistence = PersistenceService.shared

    var body: some View {
        Group {
            if puzzles.isEmpty {
                emptyState
            } else {
                puzzleList
            }
        }
        .navigationTitle("My Puzzles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { presentationMode.wrappedValue.dismiss() }
            }
        }
        .onAppear(perform: loadPuzzles)
    }

    // MARK: - Puzzle List

    var puzzleList: some View {
        List {
            Section {
                NavigationLink(destination: TrainingSessionView(trainingType: .blunderReduction, customPuzzles: puzzles)) {
                    Label("Practice All \(puzzles.count) Puzzles", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundColor(AppTheme.accent)
                }
            }

            Section {
                ForEach(puzzles) { puzzle in
                    NavigationLink(destination: TrainingSessionView(trainingType: .blunderReduction, customPuzzles: [puzzle])) {
                        PersonalPuzzleRow(puzzle: puzzle)
                    }
                }
                .onDelete(perform: deletePuzzles)
            } header: {
                Text("\(puzzles.count) Saved Puzzles")
            } footer: {
                Text("Swipe left on a puzzle to delete it.")
            }
        }
        .listStyle(.insetGrouped)
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No personal puzzles yet")
                .font(.headline)
            Text("Go to Import Games, sync your last 30 days of chess.com or Lichess games, and mistakes from those games will turn into puzzles here. You can also bookmark any position while reviewing a game.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func loadPuzzles() {
        // Newest-first, matching how PersistenceService stores them.
        puzzles = persistence.loadPersonalPuzzles()
    }

    private func deletePuzzles(at offsets: IndexSet) {
        let idsToDelete = offsets.map { puzzles[$0].id }
        puzzles.remove(atOffsets: offsets)
        persistence.deletePersonalPuzzles(ids: idsToDelete)
    }
}

// MARK: - Personal Puzzle Row
private struct PersonalPuzzleRow: View {
    let puzzle: ChessPuzzle

    private func ratingsSummary(for puzzle: ChessPuzzle) -> String {
        let whiteName = puzzle.sourceWhitePlayer ?? "White"
        let blackName = puzzle.sourceBlackPlayer ?? "Black"
        let whiteRating = puzzle.sourceWhiteRating.map { "\($0)" } ?? "?"
        let blackRating = puzzle.sourceBlackRating.map { "\($0)" } ?? "?"
        return "\(whiteName) (\(whiteRating)) vs \(blackName) (\(blackRating))"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(puzzle.theme.icon)
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(AppTheme.accentLight)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(puzzle.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(puzzle.difficulty.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let platform = puzzle.sourcePlatform {
                        Text("· \(platform)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if let date = puzzle.sourceDate {
                        Text(date, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if puzzle.sourceWhiteRating != nil || puzzle.sourceBlackRating != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(ratingsSummary(for: puzzle))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
