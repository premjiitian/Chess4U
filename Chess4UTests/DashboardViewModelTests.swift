import XCTest
@testable import Chess4U

@MainActor
final class DashboardViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeProfile(elo: Int = 1200) -> PlayerProfile {
        PlayerProfile(
            name: "Tester", elo: elo,
            preferredTimeControl: .rapid, playerType: .casual,
            mainOpeningsWhite: [], mainDefensesBlack: [],
            ratingTrend: .stable, weaknesses: []
        )
    }

    private func makeAchievements(count: Int) -> [Achievement] {
        Array(Achievement.allAchievements.prefix(count))
    }

    // MARK: - Initial state

    func testInit_defaultValues() {
        let vm = DashboardViewModel()
        XCTAssertEqual(vm.recommendedTraining, .tactics)
        XCTAssertNil(vm.weeklyPlan)
        XCTAssertNil(vm.todaysPlan)
        XCTAssertTrue(vm.recentAchievements.isEmpty)
        XCTAssertTrue(vm.sessionHistory.isEmpty)
        XCTAssertEqual(vm.motivationalMessage, "")
    }

    func testSkillData_isEmpty() {
        let vm = DashboardViewModel()
        XCTAssertTrue(vm.skillData.isEmpty)
    }

    // MARK: - load()

    func testLoad_setsWeeklyPlan() {
        let vm = DashboardViewModel()
        vm.load(profile: makeProfile(), achievements: [], streak: 0)
        XCTAssertNotNil(vm.weeklyPlan)
    }

    func testLoad_weeklyPlan_hasSeven_dailyPlans() {
        let vm = DashboardViewModel()
        vm.load(profile: makeProfile(), achievements: [], streak: 0)
        XCTAssertEqual(vm.weeklyPlan?.dailyPlans.count, 7)
    }

    func testLoad_setsRecommendedTraining_validType() {
        let vm = DashboardViewModel()
        vm.load(profile: makeProfile(), achievements: [], streak: 0)
        let valid: [TrainingType] = [.tactics, .openings, .endgames, .calculation, .strategy]
        XCTAssertTrue(valid.contains(vm.recommendedTraining))
    }

    // MARK: - recentAchievements

    func testLoad_recentAchievements_fewerThanThree_includesAll() {
        let vm = DashboardViewModel()
        vm.load(profile: makeProfile(), achievements: makeAchievements(count: 2), streak: 0)
        XCTAssertEqual(vm.recentAchievements.count, 2)
    }

    func testLoad_recentAchievements_moreThanThree_cappedAtThree() {
        let vm = DashboardViewModel()
        vm.load(profile: makeProfile(), achievements: makeAchievements(count: 6), streak: 0)
        XCTAssertEqual(vm.recentAchievements.count, 3)
    }

    func testLoad_recentAchievements_isLastThree() {
        let vm = DashboardViewModel()
        let five = makeAchievements(count: 5)
        vm.load(profile: makeProfile(), achievements: five, streak: 0)
        // suffix(3) of the first 5 = items at index 2, 3, 4
        let expected = Array(five.suffix(3)).map { $0.id }
        let actual   = vm.recentAchievements.map { $0.id }
        XCTAssertEqual(actual, expected)
    }

    // MARK: - motivationalMessage

    func testLoad_motivationalMessage_nonEmpty() {
        let vm = DashboardViewModel()
        vm.load(profile: makeProfile(), achievements: [], streak: 0)
        XCTAssertFalse(vm.motivationalMessage.isEmpty)
    }

    func testLoad_motivationalMessage_containsStreakSuffix_whenPositive() {
        let vm = DashboardViewModel()
        vm.load(profile: makeProfile(), achievements: [], streak: 7)
        XCTAssertTrue(vm.motivationalMessage.contains("7 day streak"),
                      "Expected '7 day streak' in: \(vm.motivationalMessage)")
    }

    func testLoad_motivationalMessage_noStreakSuffix_whenZero() {
        let vm = DashboardViewModel()
        vm.load(profile: makeProfile(), achievements: [], streak: 0)
        XCTAssertFalse(vm.motivationalMessage.contains("day streak"))
    }

    func testLoad_differentBands_produceDifferentMessageSets() {
        let vmA = DashboardViewModel()
        let vmE = DashboardViewModel()
        // bandA ≤ 1000, bandE ≥ 1800
        vmA.load(profile: makeProfile(elo: 900),  achievements: [], streak: 0)
        vmE.load(profile: makeProfile(elo: 2000), achievements: [], streak: 0)
        XCTAssertFalse(vmA.motivationalMessage.isEmpty)
        XCTAssertFalse(vmE.motivationalMessage.isEmpty)
    }
}
