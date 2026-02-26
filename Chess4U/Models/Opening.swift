import Foundation

// MARK: - Opening Color
enum OpeningColor: String, Codable, CaseIterable {
    case white = "White"
    case black = "Black"
    case both = "Both"
}

// MARK: - Opening Category
enum OpeningCategory: String, Codable, CaseIterable {
    case openGame = "Open Games (1.e4 e5)"
    case semiOpenGame = "Semi-Open Games (1.e4)"
    case closedGame = "Closed Games (1.d4)"
    case indianDefense = "Indian Defenses (1.d4 Nf6)"
    case flank = "Flank Openings"
}

// MARK: - Opening Variation
struct OpeningVariation: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var moves: [String]
    var description: String
    var keyIdea: String
    var fen: String

    init(name: String, moves: [String], description: String, keyIdea: String, fen: String = "") {
        self.name = name
        self.moves = moves
        self.description = description
        self.keyIdea = keyIdea
        self.fen = fen.isEmpty ? ChessBoard.startingFEN : fen
    }
}

// MARK: - Chess Opening
struct ChessOpening: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var eco: String
    var category: OpeningCategory
    var color: OpeningColor
    var moves: [String]
    var description: String
    var pawnStructure: String
    var typicalPlans: [String]
    var tacticalMotifs: [String]
    var modelGames: [String]
    var variations: [OpeningVariation]
    var fen: String
    var difficulty: PuzzleDifficulty
    var masteryLevel: Int = 0  // 0-5

    static let openingLibrary: [ChessOpening] = [
        // E4 openings
        ChessOpening(
            name: "Italian Game",
            eco: "C50",
            category: .openGame,
            color: .white,
            moves: ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4"],
            description: "One of the oldest openings. White develops naturally, aiming at the f7 pawn and controlling the center.",
            pawnStructure: "Symmetric center pawns on e4/e5. White often plays d3 (Giuoco Pianissimo) or d4 (Giuoco Piano).",
            typicalPlans: [
                "c2-c3 and d2-d4 pawn center expansion",
                "Kingside attack with Ng5, f4-f5",
                "Piece play along the c4-f7 diagonal"
            ],
            tacticalMotifs: [
                "Fried Liver Attack (Ng5, Nxf7)",
                "f7 weakness",
                "Back rank vulnerabilities"
            ],
            modelGames: ["Kasparov vs Karpov, 1986", "Morphy vs allies, 1858"],
            variations: [
                OpeningVariation(
                    name: "Giuoco Piano",
                    moves: ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"],
                    description: "The 'Quiet Game'. Black mirrors White's development.",
                    keyIdea: "Both sides fight for the center. White plays c3 and d4."
                ),
                OpeningVariation(
                    name: "Two Knights Defense",
                    moves: ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6"],
                    description: "Black counterattacks with Nf6, threatening the e4 pawn and inviting complications.",
                    keyIdea: "Black seeks active counterplay against the Italian bishop."
                ),
                OpeningVariation(
                    name: "Giuoco Pianissimo",
                    moves: ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "c2c3", "g8f6", "d2d3"],
                    description: "Slow maneuvering game. White plays d3 for a solid setup.",
                    keyIdea: "Slow build-up. White prepares a kingside attack after castling."
                )
            ],
            fen: "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3",
            difficulty: .easy
        ),
        ChessOpening(
            name: "Ruy Lopez (Spanish Game)",
            eco: "C60",
            category: .openGame,
            color: .white,
            moves: ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5"],
            description: "The most classical and deeply studied opening. White puts pressure on the e5 pawn indirectly.",
            pawnStructure: "The Ruy Lopez pawn structures are among the most complex in chess, with many typical plans.",
            typicalPlans: [
                "d2-d4 with central expansion",
                "a2-a4 to challenge the queenside",
                "f2-f4 kingside attack",
                "Minority attack on the queenside"
            ],
            tacticalMotifs: [
                "d4-d5 pawn advance",
                "Marshall Attack counterplay",
                "Noah's ark trap"
            ],
            modelGames: ["Fischer vs Spassky, 1972", "Karpov vs Kortchnoi, 1978"],
            variations: [
                OpeningVariation(
                    name: "Morphy Defense",
                    moves: ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6"],
                    description: "Most popular response. Black challenges the bishop immediately.",
                    keyIdea: "Black gains space on the queenside and asks: where does your bishop go?"
                ),
                OpeningVariation(
                    name: "Berlin Defense",
                    moves: ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "g8f6"],
                    description: "The Berlin Wall — the most solid defense, famous from Kramnik vs Kasparov 2000.",
                    keyIdea: "Black simplifies to a solid endgame with the Berlin endgame (after 4.0-0 Nxe4 5.d4 Nd6 6.Bxc6 dxc6 7.dxe5 Nf5 8.Qxd8+ Kxd8)."
                )
            ],
            fen: "r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3",
            difficulty: .medium
        ),
        ChessOpening(
            name: "Sicilian Defense",
            eco: "B20",
            category: .semiOpenGame,
            color: .black,
            moves: ["e2e4", "c7c5"],
            description: "The most popular and combative response to 1.e4. Black fights for the center asymmetrically.",
            pawnStructure: "Open c-file for Black after ...cxd4. Imbalanced pawn structures create fighting positions.",
            typicalPlans: [
                "...d5 counterattack in the center",
                "Queenside counterplay with ...b5-b4",
                "Dragon variation — fianchetto and g-file attack"
            ],
            tacticalMotifs: [
                "Back rank weaknesses",
                "d5 breaks",
                "En prise tactics on open files"
            ],
            modelGames: ["Fischer vs Spassky Game 6, 1972", "Tal vs Botvinnik, 1960"],
            variations: [
                OpeningVariation(
                    name: "Najdorf Variation",
                    moves: ["e2e4", "c7c5", "g1f3", "d7d6", "d2d4", "c5d4", "f3d4", "g8f6", "b1c3", "a7a6"],
                    description: "The sharpest and most popular Sicilian. 5...a6 prevents Nb5 and prepares ...e5 or ...b5.",
                    keyIdea: "Black prepares ...e5 or ...b5 to gain queenside space and counterplay."
                ),
                OpeningVariation(
                    name: "Dragon Variation",
                    moves: ["e2e4", "c7c5", "g1f3", "d7d6", "d2d4", "c5d4", "f3d4", "g8f6", "b1c3", "g7g6"],
                    description: "The Dragon is double-edged. Black fianchettos the bishop and fights for the g-file.",
                    keyIdea: "Black attacks on the g-file. White typically attacks on the h-file with h4-h5."
                ),
                OpeningVariation(
                    name: "Scheveningen",
                    moves: ["e2e4", "c7c5", "g1f3", "d7d6", "d2d4", "c5d4", "f3d4", "g8f6", "b1c3", "e7e6"],
                    description: "Solid and flexible. Black builds a small center with e6 and d6.",
                    keyIdea: "Black has a solid structure. Plans include ...a6, ...b5-b4 queenside play."
                )
            ],
            fen: "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2",
            difficulty: .hard
        ),
        ChessOpening(
            name: "Queen's Gambit",
            eco: "D20",
            category: .closedGame,
            color: .white,
            moves: ["d2d4", "d7d5", "c2c4"],
            description: "White offers the c4 pawn to gain central control. One of the most fundamental openings.",
            pawnStructure: "After 3...dxc4 (QGA) or 3...e6 (QGD). Rich strategic content.",
            typicalPlans: [
                "c4-c5 space gaining",
                "e2-e4 central breakthrough",
                "Minority attack (b4-b5xc6)"
            ],
            tacticalMotifs: [
                "Catalan diagonal",
                "d5 outpost",
                "Exchange sacrifice on c3"
            ],
            modelGames: ["Karpov vs Kasparov, 1985", "Carlsen vs Caruana, 2018 WC"],
            variations: [
                OpeningVariation(
                    name: "Queen's Gambit Accepted",
                    moves: ["d2d4", "d7d5", "c2c4", "d5c4"],
                    description: "Black accepts the pawn. White gets strong center, Black gets a free game.",
                    keyIdea: "After ...dxc4, White plays e4 to get a strong pawn center."
                ),
                OpeningVariation(
                    name: "Queen's Gambit Declined",
                    moves: ["d2d4", "d7d5", "c2c4", "e7e6"],
                    description: "Solid and classical. Black keeps the center and fights for equality.",
                    keyIdea: "Black has a solid position. The light-squared bishop can be problematic."
                ),
                OpeningVariation(
                    name: "Slav Defense",
                    moves: ["d2d4", "d7d5", "c2c4", "c7c6"],
                    description: "Very solid. Black supports d5 with c6 and keeps the c8 bishop active.",
                    keyIdea: "Black supports d5 and avoids the bad bishop problem of the QGD."
                )
            ],
            fen: "rnbqkbnr/ppp1pppp/8/3p4/2PP4/8/PP2PPPP/RNBQKBNR b KQkq c3 0 2",
            difficulty: .medium
        ),
        ChessOpening(
            name: "King's Indian Defense",
            eco: "E60",
            category: .indianDefense,
            color: .black,
            moves: ["d2d4", "g8f6", "c2c4", "g7g6"],
            description: "Dynamic and counterattacking. Black fianchettos and fights back in the center.",
            pawnStructure: "White has a large center, Black fights back with ...e5 or ...c5 breaks.",
            typicalPlans: [
                "...e5 to fight for the center",
                "Kingside attack with ...f5-f4",
                "Queenside counterplay with ...c5-c4"
            ],
            tacticalMotifs: [
                "f4-f5 kingside storms",
                "d5 knight outpost",
                "h3-h4 kingside attacks"
            ],
            modelGames: ["Fischer vs Spassky Game 6, 1972", "Bronstein vs Geller, 1961"],
            variations: [
                OpeningVariation(
                    name: "Classical Variation",
                    moves: ["d2d4", "g8f6", "c2c4", "g7g6", "b1c3", "f8g7", "e2e4", "d7d6", "g1f3", "e8g8", "f1e2"],
                    description: "The main line. White builds a strong center, Black plans to undermine it.",
                    keyIdea: "Black will play ...e5 to challenge the center and launch a kingside attack."
                ),
                OpeningVariation(
                    name: "Sämisch Variation",
                    moves: ["d2d4", "g8f6", "c2c4", "g7g6", "b1c3", "f8g7", "e2e4", "d7d6", "f2f3"],
                    description: "Aggressive. White prepares g4-g5 or Be3/f4 with a kingside storm.",
                    keyIdea: "The sharpest line. White attacks the kingside while Black fights for the center."
                )
            ],
            fen: "rnbqkb1r/pppppp1p/5np1/8/2PP4/8/PP2PPPP/RNBQKBNR w KQkq - 0 3",
            difficulty: .hard
        )
    ]
}
