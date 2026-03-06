import XCTest
@testable import Chess4U

final class PlayerProfileTests: XCTestCase {

    private func makeProfile(
        elo: Int = 1200,
        tactics: Double = 0, openings: Double = 0,
        endgames: Double = 0, calculation: Double = 0, strategy: Double = 0
    ) -> PlayerProfile {
        var p = PlayerProfile(
            name: "Test", elo: elo,
            preferredTimeControl: .rapid, playerType: .casual,
            mainOpeningsWhite: [], mainDefensesBlack: [],
            ratingTrend: .stable, weaknesses: []
        )
        p.tacticsAccuracy  = tactics
        p.openingAccuracy  = openings
        p.endgameAccuracy  = endgames
        p.calculationScore = calculation
        p.strategyScore    = strategy
        return p
    }

    // MARK: - band computed property

    func testBand_computedFromElo_bandA() {
        XCTAssertEqual(makeProfile(elo: 900).band, .bandA)
    }

    func testBand_computedFromElo_bandC() {
        XCTAssertEqual(makeProfile(elo: 1400).band, .bandC)
    }

    func testBand_computedFromElo_bandE() {
        XCTAssertEqual(makeProfile(elo: 2000).band, .bandE)
    }

    // MARK: - skillScores dictionary

    func testSkillScores_hasFiveEntries() {
        XCTAssertEqual(makeProfile().skillScores.count, 5)
    }

    func testSkillScores_keysAreExpected() {
        let keys = Set(makeProfile().skillScores.keys)
        XCTAssertEqual(keys, ["Tactics", "Openings", "Endgames", "Calculation", "Strategy"])
    }

    func testSkillScores_valuesMatchAccuracyFields() {
        let p = makeProfile(tactics: 72, openings: 65, endgames: 58, calculation: 80, strategy: 70)
        XCTAssertEqual(p.skillScores["Tactics"],     72,  accuracy: 0.001)
        XCTAssertEqual(p.skillScores["Openings"],    65,  accuracy: 0.001)
        XCTAssertEqual(p.skillScores["Endgames"],    58,  accuracy: 0.001)
        XCTAssertEqual(p.skillScores["Calculation"], 80,  accuracy: 0.001)
        XCTAssertEqual(p.skillScores["Strategy"],    70,  accuracy: 0.001)
    }

    // MARK: - updateElo

    func testUpdateElo_changesElo() {
        var p = makeProfile(elo: 1000)
        p.updateElo(1350)
        XCTAssertEqual(p.elo, 1350)
    }

    func testUpdateElo_changesBand() {
        var p = makeProfile(elo: 900)   // bandA
        XCTAssertEqual(p.band, .bandA)
        p.updateElo(1350)               // bandC
        XCTAssertEqual(p.band, .bandC)
    }

    // MARK: - updateAccuracy

    func testUpdateAccuracy_averagesWithCurrent() {
        var p = makeProfile(tactics: 60)
        p.updateAccuracy(tactics: 80)
        // (60 + 80) / 2 = 70
        XCTAssertEqual(p.tacticsAccuracy, 70, accuracy: 0.001)
    }

    func testUpdateAccuracy_onlyAffectsSpecifiedFields() {
        var p = makeProfile(tactics: 60, openings: 50)
        p.updateAccuracy(tactics: 80)
        XCTAssertEqual(p.tacticsAccuracy, 70,  accuracy: 0.001)  // updated
        XCTAssertEqual(p.openingAccuracy, 50,  accuracy: 0.001)  // unchanged
    }

    func testUpdateAccuracy_multipleFields() {
        var p = makeProfile(endgames: 40, calculation: 60)
        p.updateAccuracy(endgame: 80, calculation: 100)
        XCTAssertEqual(p.endgameAccuracy,  60, accuracy: 0.001)  // (40+80)/2
        XCTAssertEqual(p.calculationScore, 80, accuracy: 0.001)  // (60+100)/2
    }

    // MARK: - AppSettings defaults

    func testAppSettings_defaults() {
        let settings = AppSettings()
        XCTAssertTrue(settings.animationsEnabled)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertTrue(settings.audioCoachEnabled)
        XCTAssertEqual(settings.boardTheme, .classic)
        XCTAssertEqual(settings.pieceStyle, .standard)
        XCTAssertEqual(settings.hintLevel, .medium)
    }

    func testUIMode_allHaveNonEmptyDescription() {
        for mode in UIMode.allCases {
            XCTAssertFalse(mode.description.isEmpty, "\(mode) has empty description")
        }
    }

    func testUIMode_allHaveNonEmptyIcon() {
        for mode in UIMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty, "\(mode) has empty icon")
        }
    }

    // MARK: - recordPuzzleResult

    func testRecordPuzzleResult_solved_incrementsBothCounters() {
        var p = makeProfile()
        p.recordPuzzleResult(theme: .fork, solved: true)
        XCTAssertEqual(p.themeAttempts[PuzzleTheme.fork.rawValue], 1)
        XCTAssertEqual(p.themeSolved[PuzzleTheme.fork.rawValue], 1)
    }

    func testRecordPuzzleResult_notSolved_incrementsAttemptsOnly() {
        var p = makeProfile()
        p.recordPuzzleResult(theme: .pin, solved: false)
        XCTAssertEqual(p.themeAttempts[PuzzleTheme.pin.rawValue], 1)
        XCTAssertNil(p.themeSolved[PuzzleTheme.pin.rawValue])
    }

    func testRecordPuzzleResult_multipleCalls_accumulates() {
        var p = makeProfile()
        p.recordPuzzleResult(theme: .skewer, solved: true)
        p.recordPuzzleResult(theme: .skewer, solved: false)
        p.recordPuzzleResult(theme: .skewer, solved: true)
        XCTAssertEqual(p.themeAttempts[PuzzleTheme.skewer.rawValue], 3)
        XCTAssertEqual(p.themeSolved[PuzzleTheme.skewer.rawValue], 2)
    }

    // MARK: - accuracy(for:)

    func testAccuracy_noAttempts_returnsZero() {
        let p = makeProfile()
        XCTAssertEqual(p.accuracy(for: .fork), 0.0, accuracy: 1e-9)
    }

    func testAccuracy_allSolved_returnsOne() {
        var p = makeProfile()
        p.recordPuzzleResult(theme: .mateInOne, solved: true)
        p.recordPuzzleResult(theme: .mateInOne, solved: true)
        XCTAssertEqual(p.accuracy(for: .mateInOne), 1.0, accuracy: 1e-9)
    }

    func testAccuracy_halfSolved_returnsHalf() {
        var p = makeProfile()
        p.recordPuzzleResult(theme: .pin, solved: true)
        p.recordPuzzleResult(theme: .pin, solved: false)
        XCTAssertEqual(p.accuracy(for: .pin), 0.5, accuracy: 1e-9)
    }

    // MARK: - weakestThemes

    func testWeakestThemes_empty_whenNoAttempts() {
        let p = makeProfile()
        XCTAssertTrue(p.weakestThemes.isEmpty)
    }

    func testWeakestThemes_excluded_whenFewerThanThreeAttempts() {
        var p = makeProfile()
        // Only 2 attempts — below the 3-attempt threshold
        p.recordPuzzleResult(theme: .fork, solved: false)
        p.recordPuzzleResult(theme: .fork, solved: false)
        XCTAssertTrue(p.weakestThemes.isEmpty)
    }

    func testWeakestThemes_excluded_whenAccuracyAt40Percent() {
        var p = makeProfile()
        // 2/5 = 40% — the threshold is < 40%, so exactly 40% should be excluded
        p.recordPuzzleResult(theme: .decoy, solved: true)
        p.recordPuzzleResult(theme: .decoy, solved: true)
        p.recordPuzzleResult(theme: .decoy, solved: false)
        p.recordPuzzleResult(theme: .decoy, solved: false)
        p.recordPuzzleResult(theme: .decoy, solved: false)
        XCTAssertTrue(p.weakestThemes.isEmpty)
    }

    func testWeakestThemes_included_whenAccuracyBelow40Percent() {
        var p = makeProfile()
        // 1/4 = 25% — qualifies as weak
        p.recordPuzzleResult(theme: .deflection, solved: true)
        p.recordPuzzleResult(theme: .deflection, solved: false)
        p.recordPuzzleResult(theme: .deflection, solved: false)
        p.recordPuzzleResult(theme: .deflection, solved: false)
        XCTAssertTrue(p.weakestThemes.contains(.deflection))
    }

    func testWeakestThemes_sortedWorstFirst() {
        var p = makeProfile()
        // fork: 0/3 = 0%  (worse)
        p.recordPuzzleResult(theme: .fork, solved: false)
        p.recordPuzzleResult(theme: .fork, solved: false)
        p.recordPuzzleResult(theme: .fork, solved: false)
        // pin: 1/4 = 25% (better)
        p.recordPuzzleResult(theme: .pin, solved: true)
        p.recordPuzzleResult(theme: .pin, solved: false)
        p.recordPuzzleResult(theme: .pin, solved: false)
        p.recordPuzzleResult(theme: .pin, solved: false)
        XCTAssertEqual(p.weakestThemes.first, .fork)
        XCTAssertEqual(p.weakestThemes.last, .pin)
    }

    // MARK: - OpeningRecord

    func testOpeningRecord_initialValues() {
        let record = OpeningRecord()
        XCTAssertEqual(record.wins, 0)
        XCTAssertEqual(record.draws, 0)
        XCTAssertEqual(record.losses, 0)
        XCTAssertEqual(record.gamesPlayed, 0)
        XCTAssertEqual(record.winRate, 0.0, accuracy: 1e-9)
        XCTAssertEqual(record.scorePercent, 0.0, accuracy: 1e-9)
    }

    func testOpeningRecord_winRate_allWins() {
        var r = OpeningRecord()
        r.wins = 3
        XCTAssertEqual(r.winRate, 1.0, accuracy: 1e-9)
    }

    func testOpeningRecord_scorePercent_mixedResults() {
        var r = OpeningRecord()
        r.wins = 2; r.draws = 2; r.losses = 1   // (2 + 0.5*2) / 5 = 3/5 = 0.6
        XCTAssertEqual(r.scorePercent, 0.6, accuracy: 1e-9)
    }

    func testOpeningRecord_scorePercent_allDraws() {
        var r = OpeningRecord()
        r.draws = 4     // (0 + 0.5*4) / 4 = 0.5
        XCTAssertEqual(r.scorePercent, 0.5, accuracy: 1e-9)
    }

    // MARK: - recordOpeningResult

    func testRecordOpeningResult_win_incrementsWins() {
        var p = makeProfile()
        p.recordOpeningResult(name: "Sicilian", won: true, isDraw: false)
        XCTAssertEqual(p.openingStats["Sicilian"]?.wins, 1)
        XCTAssertEqual(p.openingStats["Sicilian"]?.losses, 0)
        XCTAssertEqual(p.openingStats["Sicilian"]?.draws, 0)
    }

    func testRecordOpeningResult_loss_incrementsLosses() {
        var p = makeProfile()
        p.recordOpeningResult(name: "King's Gambit", won: false, isDraw: false)
        XCTAssertEqual(p.openingStats["King's Gambit"]?.losses, 1)
        XCTAssertEqual(p.openingStats["King's Gambit"]?.wins, 0)
    }

    func testRecordOpeningResult_draw_incrementsDraws() {
        var p = makeProfile()
        p.recordOpeningResult(name: "Ruy Lopez", won: nil, isDraw: true)
        XCTAssertEqual(p.openingStats["Ruy Lopez"]?.draws, 1)
    }

    func testRecordOpeningResult_multipleCalls_accumulates() {
        var p = makeProfile()
        p.recordOpeningResult(name: "French", won: true,  isDraw: false)
        p.recordOpeningResult(name: "French", won: false, isDraw: false)
        p.recordOpeningResult(name: "French", won: nil,   isDraw: true)
        let record = p.openingStats["French"]!
        XCTAssertEqual(record.wins, 1)
        XCTAssertEqual(record.losses, 1)
        XCTAssertEqual(record.draws, 1)
        XCTAssertEqual(record.gamesPlayed, 3)
    }

    // MARK: - bestOpenings

    func testBestOpenings_empty_whenNoStats() {
        let p = makeProfile()
        XCTAssertTrue(p.bestOpenings.isEmpty)
    }

    func testBestOpenings_excludes_openingsWithFewerThanThreeGames() {
        var p = makeProfile()
        p.recordOpeningResult(name: "Caro-Kann", won: true, isDraw: false)
        p.recordOpeningResult(name: "Caro-Kann", won: true, isDraw: false)
        // Only 2 games — below the 3-game threshold
        XCTAssertTrue(p.bestOpenings.isEmpty)
    }

    func testBestOpenings_sortedByScorePercent_descending() {
        var p = makeProfile()
        // "E4" opening: 3 wins = 100%
        p.recordOpeningResult(name: "E4", won: true, isDraw: false)
        p.recordOpeningResult(name: "E4", won: true, isDraw: false)
        p.recordOpeningResult(name: "E4", won: true, isDraw: false)
        // "D4" opening: 0 wins, 3 draws = 50%
        p.recordOpeningResult(name: "D4", won: nil, isDraw: true)
        p.recordOpeningResult(name: "D4", won: nil, isDraw: true)
        p.recordOpeningResult(name: "D4", won: nil, isDraw: true)
        XCTAssertEqual(p.bestOpenings.first?.name, "E4")
        XCTAssertEqual(p.bestOpenings.last?.name,  "D4")
    }
}
