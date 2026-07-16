import SwiftUI

// MARK: - Study Library
/// Lichess-style Studies: annotated, chaptered lessons you can read through
/// or play as interactive "find the move" quizzes, plus user-created studies
/// built from pasted PGN.
struct StudyLibraryView: View {
    @State private var myStudies: [Study] = []
    @State private var showingCreate = false

    private var featured: [Study] { Study.builtInStudies }
    private var openingStudies: [Study] { Study.openingStudies }

    var body: some View {
        List {
            Section {
                ForEach(featured) { study in
                    NavigationLink(destination: StudyDetailView(study: study)) {
                        StudyRow(study: study)
                    }
                }
            } header: {
                Label("Featured Studies", systemImage: "book.fill")
            }

            Section {
                ForEach(openingStudies) { study in
                    NavigationLink(destination: StudyDetailView(study: study)) {
                        StudyRow(study: study)
                    }
                }
            } header: {
                Label("Opening Studies", systemImage: "square.grid.3x3.topleft.filled")
            }

            Section {
                if myStudies.isEmpty {
                    Text("Create a study from any PGN — for example a game you want to memorize, or an opening line you're building.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(myStudies) { study in
                        NavigationLink(destination: StudyDetailView(study: study)) {
                            StudyRow(study: study)
                        }
                    }
                    .onDelete(perform: deleteMyStudies)
                }
            } header: {
                Label("My Studies", systemImage: "person.fill")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Studies")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreateStudySheet { newStudy in
                PersistenceService.shared.addOrUpdateStudy(newStudy)
                loadMyStudies()
            }
        }
        .onAppear(perform: loadMyStudies)
    }

    private func loadMyStudies() {
        myStudies = PersistenceService.shared.loadStudies()
    }

    private func deleteMyStudies(at offsets: IndexSet) {
        for idx in offsets {
            PersistenceService.shared.deleteStudy(id: myStudies[idx].id)
        }
        myStudies.remove(atOffsets: offsets)
    }
}

// MARK: - Study Row
private struct StudyRow: View {
    let study: Study

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(study.title)
                .font(.subheadline)
                .fontWeight(.medium)
            if !study.subtitle.isEmpty {
                Text(study.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Text("\(study.chapters.count) chapter\(study.chapters.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundColor(AppTheme.accent)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Study Detail (chapter list)
struct StudyDetailView: View {
    let study: Study

    var body: some View {
        List {
            if !study.subtitle.isEmpty {
                Section {
                    Text(study.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Section {
                ForEach(Array(study.chapters.enumerated()), id: \.element.id) { idx, chapter in
                    NavigationLink(destination: StudyChapterView(study: study, chapter: chapter)) {
                        HStack(spacing: 12) {
                            Text("\(idx + 1)")
                                .font(.headline)
                                .foregroundColor(AppTheme.accent)
                                .frame(width: 28, height: 28)
                                .background(AppTheme.accentLight)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chapter.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(chapter.moves.count) moves")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Chapters")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(study.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Chapter Player
struct StudyChapterView: View {
    let study: Study
    let chapter: StudyChapter
    @StateObject private var vm = StudyChapterViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Mode picker: read the lesson, or be quizzed on it.
                Picker("Mode", selection: $vm.mode) {
                    Text("Study").tag(StudyMode.browse)
                    Text("Quiz").tag(StudyMode.quiz)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ChessBoardView(vm: vm.boardVM, interactive: vm.mode == .quiz && vm.quizState == .yourMove)
                    .padding(.horizontal, 8)
                    .onChange(of: vm.boardVM.game.moves.count) { _ in
                        if let lastMove = vm.boardVM.game.moves.last {
                            vm.handleBoardMove(lastMove)
                        }
                    }

                // Commentary card
                commentCard

                // Move strip
                moveStrip

                // Controls
                if vm.mode == .browse {
                    browseControls
                } else {
                    quizControls
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.load(chapter: chapter)
        }
        .onChange(of: vm.mode) { _ in
            vm.resetForMode()
        }
    }

    private var commentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: vm.mode == .quiz ? "questionmark.circle.fill" : "text.book.closed.fill")
                    .foregroundColor(AppTheme.accent)
                Text(vm.commentTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            Text(vm.commentBody)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    private var moveStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(vm.displayMoves.enumerated()), id: \.offset) { idx, san in
                        Text(san)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(idx == vm.reachedPlies - 1 ? AppTheme.accent : Color(.systemBackground))
                            .foregroundColor(idx == vm.reachedPlies - 1 ? .white :
                                             idx < vm.reachedPlies ? .primary : .secondary)
                            .cornerRadius(8)
                            .id(idx)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 40)
            .onChange(of: vm.reachedPlies) { plies in
                if plies > 0 {
                    withAnimation { proxy.scrollTo(plies - 1, anchor: .center) }
                }
            }
        }
    }

    private var browseControls: some View {
        HStack(spacing: 20) {
            Button { vm.goToStart() } label: { Image(systemName: "backward.end.fill") }
            Button { vm.stepBack() } label: { Image(systemName: "backward.fill") }
            Text("\(vm.reachedPlies)/\(chapter.moves.count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(minWidth: 44)
            Button { vm.stepForward() } label: { Image(systemName: "forward.fill") }
            Button { vm.goToEnd() } label: { Image(systemName: "forward.end.fill") }
        }
        .font(.title2)
        .foregroundColor(.primary)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    private var quizControls: some View {
        HStack(spacing: 12) {
            Button {
                vm.quizHint()
            } label: {
                Label("Hint", systemImage: "lightbulb")
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.yellow.opacity(0.15))
                    .foregroundColor(.yellow)
                    .cornerRadius(10)
            }
            Button {
                vm.resetForMode()
            } label: {
                Label("Restart", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(AppTheme.accentLight)
                    .foregroundColor(AppTheme.accent)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Chapter View Model
enum StudyMode { case browse, quiz }
enum QuizState { case yourMove, opponentReplying, complete }

@MainActor
final class StudyChapterViewModel: ObservableObject {
    @Published var boardVM = ChessBoardViewModel()
    @Published var mode: StudyMode = .browse
    @Published var quizState: QuizState = .yourMove
    /// How many plies of the chapter line are currently on the board.
    @Published var reachedPlies: Int = 0
    @Published var commentTitle: String = ""
    @Published var commentBody: String = ""
    /// Figurine-SAN for every chapter move, precomputed once.
    @Published var displayMoves: [String] = []

    private var chapter: StudyChapter?
    /// In quiz mode, the side the learner plays (side to move at chapter start).
    private var quizColor: PieceColor = .white
    private let engine = ChessEngineService.shared

    func load(chapter: StudyChapter) {
        self.chapter = chapter
        quizColor = ChessGame(fen: chapter.startFEN).board.activeColor
        displayMoves = Self.figurineLine(startFEN: chapter.startFEN, moves: chapter.moves.map { $0.uci })
        resetForMode()
    }

    func resetForMode() {
        guard let chapter = chapter else { return }
        boardVM = ChessBoardViewModel(fen: chapter.startFEN)
        boardVM.isFlipped = quizColor == .black
        reachedPlies = 0
        quizState = .yourMove
        if mode == .quiz {
            commentTitle = "Your move"
            commentBody = "Find the move the study recommends here. (\(quizColor == .white ? "White" : "Black") to play.)"
        } else {
            commentTitle = chapter.title
            commentBody = chapter.intro.isEmpty ? "Step through the moves with the arrows below." : chapter.intro
        }
    }

    // MARK: Browse mode
    func goToStart() { rebuild(to: 0) }
    func goToEnd() { rebuild(to: chapter?.moves.count ?? 0) }
    func stepBack() { rebuild(to: max(0, reachedPlies - 1)) }
    func stepForward() { rebuild(to: min((chapter?.moves.count ?? 0), reachedPlies + 1)) }

    private func rebuild(to plies: Int) {
        guard let chapter = chapter else { return }
        boardVM = ChessBoardViewModel(fen: chapter.startFEN)
        boardVM.isFlipped = quizColor == .black
        var lastMove: ChessMove? = nil
        for studyMove in chapter.moves.prefix(plies) {
            if let move = engine.move(fromUCI: studyMove.uci, board: boardVM.game.board) {
                boardVM.game.makeMove(move)
                lastMove = move
            }
        }
        boardVM.lastMove = lastMove
        reachedPlies = plies

        if plies == 0 {
            commentTitle = chapter.title
            commentBody = chapter.intro.isEmpty ? "Step through the moves with the arrows below." : chapter.intro
        } else {
            let studyMove = chapter.moves[plies - 1]
            commentTitle = displayMoves.indices.contains(plies - 1) ? displayMoves[plies - 1] : studyMove.uci
            commentBody = studyMove.comment.isEmpty ? "…" : studyMove.comment
        }
    }

    // MARK: Quiz mode
    func handleBoardMove(_ move: ChessMove) {
        guard mode == .quiz, quizState == .yourMove,
              let chapter = chapter, reachedPlies < chapter.moves.count else { return }
        guard move.piece.color == quizColor else { return }

        let expected = chapter.moves[reachedPlies].uci
        var played = move.longAlgebraic
        if let promo = move.promotionPiece { played += String(promo.fenChar) }

        if played == expected || move.longAlgebraic == expected {
            let solvedMove = chapter.moves[reachedPlies]
            reachedPlies += 1
            commentTitle = "✅ " + (displayMoves.indices.contains(reachedPlies - 1) ? displayMoves[reachedPlies - 1] : expected)
            commentBody = solvedMove.comment.isEmpty ? "Correct!" : solvedMove.comment
            playOpponentReplyIfNeeded()
        } else {
            // Undo the wrong move and let them retry.
            quizState = .opponentReplying
            commentTitle = "❌ Not the study move"
            commentBody = "Take another look — use Hint if you're stuck."
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard let self = self else { return }
                self.boardVM.undoLastMove()
                self.quizState = .yourMove
            }
        }
    }

    private func playOpponentReplyIfNeeded() {
        guard let chapter = chapter else { return }
        guard reachedPlies < chapter.moves.count else {
            quizState = .complete
            commentTitle = "🏆 Chapter complete"
            commentBody = "You found every move of the line. Switch back to Study mode to reread the commentary, or pick the next chapter."
            return
        }
        quizState = .opponentReplying
        let reply = chapter.moves[reachedPlies]
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard let self = self, self.quizState == .opponentReplying else { return }
            if let move = self.engine.move(fromUCI: reply.uci, board: self.boardVM.game.board) {
                self.boardVM.executeMove(move)
                self.reachedPlies += 1
                if !reply.comment.isEmpty {
                    self.commentBody += "\n\nOpponent: " + reply.comment
                }
            }
            if self.reachedPlies >= (self.chapter?.moves.count ?? 0) {
                self.quizState = .complete
                self.commentTitle = "🏆 Chapter complete"
                self.commentBody = "You found every move of the line."
            } else {
                self.quizState = .yourMove
            }
        }
    }

    func quizHint() {
        guard let chapter = chapter, reachedPlies < chapter.moves.count else { return }
        let uci = chapter.moves[reachedPlies].uci
        commentTitle = "💡 Hint"
        commentBody = "Move the piece on \(uci.prefix(2))."
    }

    // MARK: Figurine SAN
    static func figurineLine(startFEN: String, moves: [String]) -> [String] {
        let engine = ChessEngineService.shared
        var board = ChessGame(fen: startFEN).board
        var result: [String] = []
        for uci in moves {
            guard let move = engine.move(fromUCI: uci, board: board) else {
                result.append(uci)
                continue
            }
            let san = engine.san(move, on: board)
            let display: String
            if move.isCastling {
                display = san
            } else if move.piece.type == .pawn {
                display = move.piece.symbolForColor + san
            } else {
                display = move.piece.symbolForColor + String(san.dropFirst())
            }
            let number = board.activeColor == .white ? "\(board.fullMoveNumber)." : ""
            result.append(number + display)
            board = engine.applyMove(move, to: board)
        }
        return result
    }
}

// MARK: - Create Study Sheet
struct CreateStudySheet: View {
    @Environment(\.presentationMode) private var presentationMode
    let onCreate: (Study) -> Void

    @State private var title: String = ""
    @State private var pgnText: String = ""
    @State private var errorText: String? = nil

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Study title", text: $title)
                } header: {
                    Text("Title")
                }

                Section {
                    TextEditor(text: $pgnText)
                        .frame(minHeight: 140)
                        .font(.system(.caption, design: .monospaced))
                } header: {
                    Text("PGN")
                } footer: {
                    Text("Paste a game or line in PGN. Each pasted game becomes a chapter you can browse or quiz yourself on. You can copy PGN from any finished game in Free Play, or from chess.com/Lichess.")
                }

                if let errorText = errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("New Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") { create() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || pgnText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() {
        guard let game = PGNImporter.importGame(pgnText), !game.moves.isEmpty else {
            errorText = "Couldn't read any moves from that PGN. Make sure it's a standard PGN game."
            return
        }
        var chapter = StudyChapter(title: "Chapter 1")
        chapter.moves = game.moves.map { StudyMove($0.longAlgebraic + ($0.promotionPiece.map { String($0.fenChar) } ?? "")) }
        var study = Study(title: title.trimmingCharacters(in: .whitespaces))
        study.subtitle = "\(game.whitePlayer) vs \(game.blackPlayer)"
        study.chapters = [chapter]
        onCreate(study)
        presentationMode.wrappedValue.dismiss()
    }
}
