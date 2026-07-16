import Foundation

// MARK: - Study (Lichess-style annotated lessons)
/// A study is a collection of chapters; each chapter is a single annotated
/// line of moves from a starting position. Modeled on Lichess's Study
/// feature: browse the line with commentary, or play it as an interactive
/// "find the move" lesson.

struct StudyMove: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    /// Long-algebraic UCI ("e2e4", "e7e8q").
    var uci: String
    /// Author commentary revealed when this move is reached.
    var comment: String = ""

    init(_ uci: String, _ comment: String = "") {
        self.uci = uci
        self.comment = comment
    }
}

struct StudyChapter: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    /// Shown before the first move is played.
    var intro: String = ""
    var startFEN: String = ChessBoard.startingFEN
    var moves: [StudyMove] = []
}

struct Study: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var subtitle: String = ""
    /// Built-in studies ship with the app and can't be edited or deleted.
    var isBuiltIn: Bool = false
    var createdDate: Date = Date()
    var chapters: [StudyChapter] = []
}

// MARK: - Built-in studies
// Every move line below was machine-validated for legality with python-chess
// before being embedded (several of the app's original puzzle lines turned
// out to be illegal, so no line ships unverified anymore).
extension Study {

    static let builtInStudies: [Study] = [
        italianGameStudy,
        tacticsFundamentalsStudy,
        backRankStudy,
        kingPawnEndgameStudy,
    ]

    /// One study per library opening, generated from the existing opening
    /// library (each variation becomes a chapter). These lines are the same
    /// ones Variation Practice drills, so they're already exercised in-app.
    static var openingStudies: [Study] {
        ChessOpening.openingLibrary.map { opening in
            var study = Study(title: opening.name,
                              subtitle: "\(opening.eco) · \(opening.category.rawValue)",
                              isBuiltIn: true)
            var mainChapter = StudyChapter(title: "Main Line", intro: opening.description)
            mainChapter.moves = opening.moves.enumerated().map { idx, uci in
                StudyMove(uci, idx == opening.moves.count - 1
                          ? (opening.typicalPlans.first ?? "")
                          : "")
            }
            study.chapters = [mainChapter] + opening.variations.map { variation in
                var ch = StudyChapter(title: variation.name, intro: variation.description)
                ch.moves = variation.moves.enumerated().map { idx, uci in
                    StudyMove(uci, idx == variation.moves.count - 1 ? variation.keyIdea : "")
                }
                return ch
            }
            return study
        }
    }

    static let italianGameStudy: Study = {
        var study = Study(title: "Italian Game: Move by Move",
                          subtitle: "Why each move is played, one at a time",
                          isBuiltIn: true)

        var pianissimo = StudyChapter(
            title: "Giuoco Pianissimo — The Quiet Build-Up",
            intro: "The Italian Game is one of the oldest and most instructive openings. This chapter explains the purpose behind every single move of the modern main line.")
        pianissimo.moves = [
            StudyMove("e2e4", "Stake a claim in the center and open lines for the queen and light-squared bishop."),
            StudyMove("e7e5", "Black mirrors, fighting for the same central squares."),
            StudyMove("g1f3", "Develop with tempo — the knight immediately attacks the e5 pawn."),
            StudyMove("b8c6", "Defends e5 while developing a piece. Development with purpose."),
            StudyMove("f1c4", "The Italian bishop. It points straight at f7, the weakest square in Black's camp — only the king defends it."),
            StudyMove("f8c5", "Black replies symmetrically: the Giuoco Piano. The bishop eyes White's own weak point, f2."),
            StudyMove("c2c3", "A key idea: prepare d2-d4 to build the big pawn center. The pawn also takes the d4 square away from Black's knight."),
            StudyMove("g8f6", "Black develops and counterattacks e4 — White must now make a decision about the center."),
            StudyMove("d2d3", "The Pianissimo ('very quiet') choice: protect e4, castle quickly, and only later expand with d4 or attack on the kingside. Slow, but full of poison."),
        ]

        study.chapters = [pianissimo]
        return study
    }()

    static let tacticsFundamentalsStudy: Study = {
        var study = Study(title: "Attacking f7: Classic Traps",
                          subtitle: "Scholar's Mate and the Fried Liver Attack",
                          isBuiltIn: true)

        var scholars = StudyChapter(
            title: "The f7 Weakness — Scholar's Mate Pattern",
            intro: "f7 (and f2 for White) is defended only by the king at the start of the game. When the defending knight has left the kingside, queen and bishop can strike together.",
            startFEN: "r1bqkb1r/pppp1ppp/2n5/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 4 4")
        scholars.moves = [
            StudyMove("f3f7", "Qxf7# — checkmate! The queen is protected by the c4 bishop, so the king can't take. Every escape square is covered. This is why ...Nf6 (blocking and defending) is the standard defense to early queen sorties."),
        ]

        var friedLiver = StudyChapter(
            title: "The Fried Liver Attack",
            intro: "From the Two Knights Defense, White can sacrifice a knight on f7 to drag the black king into the open. Play through the whole line from move one.")
        friedLiver.moves = [
            StudyMove("e2e4", ""),
            StudyMove("e7e5", ""),
            StudyMove("g1f3", ""),
            StudyMove("b8c6", ""),
            StudyMove("f1c4", "The Italian bishop takes aim at f7."),
            StudyMove("g8f6", "The Two Knights Defense — Black counterattacks e4 instead of quietly developing the bishop."),
            StudyMove("f3g5", "Only here does Ng5 make sense: it attacks f7 a second time, and only the king defends it."),
            StudyMove("d7d5", "The main defense: block the bishop's diagonal. Almost everything else loses material immediately."),
            StudyMove("e4d5", "Taking — now the c6 knight can't recapture because the bishop would pin it."),
            StudyMove("f6d5", "Natural but risky! Taking with the knight walks into the sacrifice. Safer is 5...Na5, hitting the bishop."),
            StudyMove("g5f7", "The Fried Liver: Nxf7! forks queen and rook, and after Kxf7 White follows with Qf3+ dragging the king forward. Black's king will live in the center for the rest of the game."),
        ]

        study.chapters = [scholars, friedLiver]
        return study
    }()

    static let backRankStudy: Study = {
        var study = Study(title: "Back-Rank Mate Patterns",
                          subtitle: "The mate every player falls for at least once",
                          isBuiltIn: true)

        var basic = StudyChapter(
            title: "The Basic Pattern",
            intro: "A castled king with unmoved pawns in front of it is safe from most attacks — but those same pawns become a prison when a rook or queen lands on the back rank.",
            startFEN: "6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1")
        basic.moves = [
            StudyMove("e1e8", "Re8# — mate. The f7/g7/h7 pawns block every escape square. The cure: make 'luft' (air) with a quiet pawn move like h3/h6 before it matters."),
        ]

        var trade = StudyChapter(
            title: "Winning the Defender",
            intro: "When the back rank is covered by exactly one defender, capturing that defender can be decisive — the recapture is impossible if it allows mate.",
            startFEN: "3r2k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1")
        trade.moves = [
            StudyMove("d1d8", "Rxd8# — Black's rook was the only defender of d8, and no other piece can recapture. Count the defenders of your back rank, not just the attackers."),
        ]

        var openFile = StudyChapter(
            title: "The Open File Invasion",
            intro: "Rooks fight for open files precisely because the file is the road to the eighth rank.",
            startFEN: "2r3k1/5ppp/8/8/8/8/5PPP/2R3K1 w - - 0 1")
        openFile.moves = [
            StudyMove("c1c8", "Rxc8# — same pattern from the c-file. In your own games, ask before every quiet move: is my back rank safe right now?"),
        ]

        study.chapters = [basic, trade, openFile]
        return study
    }()

    static let kingPawnEndgameStudy: Study = {
        var study = Study(title: "King & Pawn Endgames",
                          subtitle: "Opposition and key squares — engine-verified lines",
                          isBuiltIn: true)

        var keySquares = StudyChapter(
            title: "The King Leads the Way",
            intro: "King and pawn versus lone king is the endgame every other endgame can simplify into. The single most important idea: the KING goes first, the pawn follows. This whole line is Stockfish-verified.",
            startFEN: "4k3/8/8/8/8/8/4P3/4K3 w - - 0 1")
        keySquares.moves = [
            StudyMove("e1f2", "The king steps up first. The pawn stays home — it isn't going anywhere, and every rank the king gains matters."),
            StudyMove("e8f8", "Black shadows the white king, trying to stand in front of the pawn's path."),
            StudyMove("f2e3", "Zig-zagging forward. The king heads for the squares IN FRONT of its own pawn — d4, e4, f4 and beyond."),
            StudyMove("f8e7", "Black keeps the direct opposition in sight, but must constantly guess which side White's king will pass."),
            StudyMove("e3f3", "A waiting-style step. White can afford to maneuver — Black can only react."),
            StudyMove("e7d7", "Black commits to the queenside…"),
            StudyMove("f3f4", "…so White immediately gains ground on the kingside. This is outflanking in action."),
            StudyMove("d7e7", "Black rushes back, but it's too late to keep the king out."),
            StudyMove("f4e5", "The white king reaches e5 — in front of its pawn. From here the win is guaranteed: the king clears the road to e8, then the pawn walks through. When defending, remember the reverse: keep your king in front of the enemy pawn."),
        ]

        var outflank = StudyChapter(
            title: "Outflanking",
            intro: "When the defending king is slightly offside, the attacking king cuts AROUND it rather than pushing straight ahead. Engine-verified line.",
            startFEN: "8/5k2/8/4K3/4P3/8/8/8 w - - 0 1")
        outflank.moves = [
            StudyMove("e5d6", "Kd6! The king slips around the defender instead of confronting it. Now e5–e6–e7 becomes an escort route."),
            StudyMove("f7g7", "Black tries to stay in touch from the side."),
            StudyMove("e4e5", "Only now does the pawn advance — the king already controls its path."),
            StudyMove("g7g6", "Black harasses from the flank, a ghost of counterplay."),
            StudyMove("d6e6", "Ke6 seals it: the king shepherds the pawn to e8 and Black can never get back in front. Notice the pattern — king first, pawn second, every time."),
        ]

        study.chapters = [keySquares, outflank]
        return study
    }()
}
