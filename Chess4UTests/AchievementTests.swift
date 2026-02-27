import XCTest
@testable import Chess4U

final class AchievementTests: XCTestCase {

    // MARK: - Helpers

    private func makeProfile(
        elo: Int = 1000,
        puzzlesSolved: Int = 0,
        sessions: Int = 0,
        tactics: Double = 0,
        openings: Double = 0,
        endgames: Double = 0,
        calculation: Double = 0,
        strategy: Double = 0
    ) -> PlayerProfile {
        var p = PlayerProfile(
            name: "Test", elo: elo,
            preferredTimeControl: .rapid, playerType: .casual,
            mainOpeningsWhite: [], mainDefensesBlack: [],
            ratingTrend: .stable, weaknesses: []
        )
        p.totalPuzzlesSolved = puzzlesSolved
        p.sessionsCompleted  = sessions
        p.tacticsAccuracy    = tactics
        p.openingAccuracy    = openings
        p.endgameAccuracy    = endgames
        p.calculationScore   = calculation
        p.strategyScore      = strategy
        return p
    }

    private func achievement(_ id: String) -> Achievement {
        Achievement.allAchievements.first { $0.id == id }!
    }

    // MARK: - Database integrity

    func testAllAchievements_uniqueIDs() {
        let ids = Achievement.allAchievements.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate IDs in allAchievements")
    }

    func testAllAchievements_nonEmptyMetadata() {
        for a in Achievement.allAchievements {
            XCTAssertFalse(a.title.isEmpty,       "\(a.id) has empty title")
            XCTAssertFalse(a.description.isEmpty, "\(a.id) has empty description")
            XCTAssertFalse(a.icon.isEmpty,        "\(a.id) has empty icon")
        }
    }

    // MARK: - isEarned (struct property)

    func testIsEarned_property_falseWithoutDate() {
        let a = Achievement(id: "x", title: "T", description: "D",
                            icon: "y", category: .tactics, rarity: .common)
        XCTAssertFalse(a.isEarned)
    }

    func testIsEarned_property_trueWithDate() {
        var a = Achievement(id: "x", title: "T", description: "D",
                            icon: "y", category: .tactics, rarity: .common)
        a.earnedDate = Date()
        XCTAssertTrue(a.isEarned)
    }

    // MARK: - isEarned(profile:streak:): puzzle milestones

    func testFirstPuzzle_earned() {
        XCTAssertTrue(achievement("first_puzzle").isEarned(profile: makeProfile(puzzlesSolved: 1), streak: 0))
    }

    func testFirstPuzzle_notEarned() {
        XCTAssertFalse(achievement("first_puzzle").isEarned(profile: makeProfile(), streak: 0))
    }

    func testPuzzle100_boundary() {
        let a = achievement("puzzle_100")
        XCTAssertFalse(a.isEarned(profile: makeProfile(puzzlesSolved: 99), streak: 0))
        XCTAssertTrue(a.isEarned(profile: makeProfile(puzzlesSolved: 100), streak: 0))
    }

    // MARK: - isEarned(profile:streak:): streak milestones

    func testStreak3_boundary() {
        let a = achievement("streak_3")
        XCTAssertFalse(a.isEarned(profile: makeProfile(), streak: 2))
        XCTAssertTrue(a.isEarned(profile: makeProfile(), streak: 3))
    }

    func testStreak7_boundary() {
        let a = achievement("streak_7")
        XCTAssertFalse(a.isEarned(profile: makeProfile(), streak: 6))
        XCTAssertTrue(a.isEarned(profile: makeProfile(), streak: 7))
    }

    // MARK: - isEarned(profile:streak:): Elo milestones

    func testElo1000_boundary() {
        let a = achievement("elo_1000")
        XCTAssertFalse(a.isEarned(profile: makeProfile(elo: 999), streak: 0))
        XCTAssertTrue(a.isEarned(profile: makeProfile(elo: 1000), streak: 0))
    }

    func testElo1500_boundary() {
        let a = achievement("elo_1500")
        XCTAssertFalse(a.isEarned(profile: makeProfile(elo: 1499), streak: 0))
        XCTAssertTrue(a.isEarned(profile: makeProfile(elo: 1500), streak: 0))
    }

    // MARK: - isEarned(profile:streak:): skill accuracy

    func testTacticsMaster_boundary() {
        let a = achievement("tactics_master")
        XCTAssertFalse(a.isEarned(profile: makeProfile(tactics: 79.9), streak: 0))
        XCTAssertTrue(a.isEarned(profile: makeProfile(tactics: 80.0), streak: 0))
    }

    func testOpeningSpecialist_boundary() {
        let a = achievement("opening_specialist")
        XCTAssertFalse(a.isEarned(profile: makeProfile(openings: 74.9), streak: 0))
        XCTAssertTrue(a.isEarned(profile: makeProfile(openings: 75.0), streak: 0))
    }

    func testEndgameTechnician_boundary() {
        let a = achievement("endgame_technician")
        XCTAssertFalse(a.isEarned(profile: makeProfile(endgames: 74.9), streak: 0))
        XCTAssertTrue(a.isEarned(profile: makeProfile(endgames: 75.0), streak: 0))
    }

    // MARK: - Unknown achievement ID

    func testUnknownID_alwaysFalse() {
        let a = Achievement(id: "nonexistent", title: "X", description: "Y",
                            icon: "z", category: .tactics, rarity: .common)
        let richProfile = makeProfile(elo: 9999, puzzlesSolved: 9999, sessions: 9999,
                                      tactics: 100, openings: 100, endgames: 100,
                                      calculation: 100, strategy: 100)
        XCTAssertFalse(a.isEarned(profile: richProfile, streak: 999))
    }
}
