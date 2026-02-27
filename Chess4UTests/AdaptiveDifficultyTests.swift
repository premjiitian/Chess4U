import XCTest
@testable import Chess4U

final class AdaptiveDifficultyTests: XCTestCase {

    // Each test creates its own fresh instance so there is no shared state.

    private func makeSvc() -> AdaptiveDifficultyService { AdaptiveDifficultyService() }

    private func makeProfile(elo: Int) -> PlayerProfile {
        PlayerProfile(
            name: "Test", elo: elo,
            preferredTimeControl: .rapid, playerType: .casual,
            mainOpeningsWhite: [], mainDefensesBlack: [],
            ratingTrend: .stable, weaknesses: []
        )
    }

    // MARK: - recommendedSettings (pure function, no state)

    func testRecommendedSettings_bandA() {
        let s = makeSvc().recommendedSettings(for: makeProfile(elo: 900))
        XCTAssertEqual(s.puzzleDifficulty, .beginner)
        XCTAssertTrue(s.showHints)
        XCTAssertTrue(s.showArrows)
        XCTAssertFalse(s.showEvalBar)
        XCTAssertEqual(s.calculationDepth, 2)
        XCTAssertEqual(s.timePerMove, 120)
    }

    func testRecommendedSettings_bandB() {
        let s = makeSvc().recommendedSettings(for: makeProfile(elo: 1100))
        XCTAssertEqual(s.puzzleDifficulty, .easy)
        XCTAssertTrue(s.showHints)
        XCTAssertFalse(s.showArrows)
        XCTAssertFalse(s.showEvalBar)
        XCTAssertEqual(s.calculationDepth, 3)
        XCTAssertEqual(s.timePerMove, 90)
    }

    func testRecommendedSettings_bandC() {
        let s = makeSvc().recommendedSettings(for: makeProfile(elo: 1400))
        XCTAssertEqual(s.puzzleDifficulty, .medium)
        XCTAssertFalse(s.showHints)
        XCTAssertFalse(s.showArrows)
        XCTAssertTrue(s.showEvalBar)
        XCTAssertEqual(s.calculationDepth, 5)
        XCTAssertEqual(s.timePerMove, 60)
    }

    func testRecommendedSettings_bandD() {
        let s = makeSvc().recommendedSettings(for: makeProfile(elo: 1700))
        XCTAssertEqual(s.puzzleDifficulty, .hard)
        XCTAssertFalse(s.showHints)
        XCTAssertFalse(s.showArrows)
        XCTAssertTrue(s.showEvalBar)
        XCTAssertEqual(s.calculationDepth, 8)
        XCTAssertEqual(s.timePerMove, 45)
    }

    func testRecommendedSettings_bandE() {
        let s = makeSvc().recommendedSettings(for: makeProfile(elo: 2000))
        XCTAssertEqual(s.puzzleDifficulty, .expert)
        XCTAssertFalse(s.showHints)
        XCTAssertFalse(s.showArrows)
        XCTAssertTrue(s.showEvalBar)
        XCTAssertEqual(s.calculationDepth, 12)
        XCTAssertEqual(s.timePerMove, 30)
    }

    // MARK: - successRate and averageTime

    func testSuccessRate_initiallyZero() {
        XCTAssertEqual(makeSvc().successRate, 0)
    }

    func testAverageTime_initiallyZero() {
        XCTAssertEqual(makeSvc().averageTime, 0)
    }

    func testSuccessRate_allCorrect() {
        let svc = makeSvc()
        for _ in 0..<5 { svc.recordResult(correct: true, timeSpent: 10) }
        XCTAssertEqual(svc.successRate, 1.0, accuracy: 0.001)
    }

    func testSuccessRate_halfCorrect() {
        let svc = makeSvc()
        svc.recordResult(correct: true,  timeSpent: 10)
        svc.recordResult(correct: false, timeSpent: 10)
        XCTAssertEqual(svc.successRate, 0.5, accuracy: 0.001)
    }

    func testAverageTime_computed() {
        let svc = makeSvc()
        svc.recordResult(correct: true, timeSpent: 20)
        svc.recordResult(correct: true, timeSpent: 40)
        XCTAssertEqual(svc.averageTime, 30, accuracy: 0.001)
    }

    // MARK: - Auto difficulty adjustment

    func testDifficulty_increasesAfterHighSuccessRate() {
        let svc = makeSvc()
        svc.currentDifficulty = .easy  // room to increase
        // 5/5 = 100% > 80% threshold
        for _ in 0..<5 { svc.recordResult(correct: true, timeSpent: 5) }
        XCTAssertEqual(svc.currentDifficulty, .medium)
        XCTAssertFalse(svc.shouldShowHints)
    }

    func testDifficulty_decreasesAndEnablesSupportAfterLowSuccessRate() {
        let svc = makeSvc()
        svc.currentDifficulty = .hard  // room to decrease
        // 0/5 = 0% < 50% threshold
        for _ in 0..<5 { svc.recordResult(correct: false, timeSpent: 60) }
        XCTAssertEqual(svc.currentDifficulty, .medium)
        XCTAssertTrue(svc.shouldShowHints)
        XCTAssertTrue(svc.shouldShowArrows)
    }

    func testDifficulty_noChangeInMiddleRange() {
        let svc = makeSvc()
        svc.currentDifficulty = .medium
        // 3/5 = 60% — between 50% and 80%, no change
        svc.recordResult(correct: true,  timeSpent: 10)
        svc.recordResult(correct: true,  timeSpent: 10)
        svc.recordResult(correct: true,  timeSpent: 10)
        svc.recordResult(correct: false, timeSpent: 10)
        svc.recordResult(correct: false, timeSpent: 10)
        XCTAssertEqual(svc.currentDifficulty, .medium)
        XCTAssertFalse(svc.shouldShowHints)
    }

    func testDifficulty_doesNotExceedMaximum() {
        let svc = makeSvc()
        svc.currentDifficulty = .expert
        for _ in 0..<5 { svc.recordResult(correct: true, timeSpent: 1) }
        XCTAssertEqual(svc.currentDifficulty, .expert)
        XCTAssertFalse(svc.difficultyMessage.isEmpty)  // shows "maximum" message
    }
}
