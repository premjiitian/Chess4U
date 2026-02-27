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
}
