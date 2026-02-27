import XCTest
@testable import Chess4U

final class TrainingSessionTests: XCTestCase {

    private func makeSession(
        type: TrainingType = .tactics,
        band: PlayerBand = .bandB,
        correctMoves: Int = 0,
        totalMoves: Int = 0,
        puzzlesSolved: Int = 0,
        puzzlesAttempted: Int = 0,
        endDate: Date? = nil
    ) -> TrainingSession {
        var s = TrainingSession(type: type, playerBand: band, startDate: Date(timeIntervalSinceReferenceDate: 0))
        s.correctMoves       = correctMoves
        s.totalMoves         = totalMoves
        s.puzzlesSolved      = puzzlesSolved
        s.puzzlesAttempted   = puzzlesAttempted
        s.endDate            = endDate
        return s
    }

    // MARK: - accuracy

    func testAccuracy_zeroWhenNoMoves() {
        XCTAssertEqual(makeSession().accuracy, 0)
    }

    func testAccuracy_100PercentWhenAllCorrect() {
        XCTAssertEqual(makeSession(correctMoves: 5, totalMoves: 5).accuracy, 100, accuracy: 0.001)
    }

    func testAccuracy_60Percent() {
        XCTAssertEqual(makeSession(correctMoves: 3, totalMoves: 5).accuracy, 60, accuracy: 0.001)
    }

    // MARK: - puzzleAccuracy

    func testPuzzleAccuracy_zeroWhenNoneAttempted() {
        XCTAssertEqual(makeSession().puzzleAccuracy, 0)
    }

    func testPuzzleAccuracy_100WhenAllSolved() {
        XCTAssertEqual(makeSession(puzzlesSolved: 4, puzzlesAttempted: 4).puzzleAccuracy, 100, accuracy: 0.001)
    }

    func testPuzzleAccuracy_75Percent() {
        XCTAssertEqual(makeSession(puzzlesSolved: 3, puzzlesAttempted: 4).puzzleAccuracy, 75, accuracy: 0.001)
    }

    // MARK: - isComplete / duration

    func testIsComplete_falseWithoutEndDate() {
        XCTAssertFalse(makeSession().isComplete)
    }

    func testIsComplete_trueWithEndDate() {
        let s = makeSession(endDate: Date())
        XCTAssertTrue(s.isComplete)
    }

    func testDuration_nilWithoutEndDate() {
        XCTAssertNil(makeSession().duration)
    }

    func testDuration_correctInterval() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end   = Date(timeIntervalSinceReferenceDate: 600)  // 10 minutes later
        var s = TrainingSession(type: .tactics, playerBand: .bandA, startDate: start)
        s.endDate = end
        XCTAssertEqual(s.duration, 600, accuracy: 0.001)
    }

    // MARK: - TrainingType metadata

    func testTrainingType_allHaveNonZeroEstimatedMinutes() {
        for type in TrainingType.allCases {
            XCTAssertGreaterThan(type.estimatedMinutes, 0, "\(type) has 0 estimatedMinutes")
        }
    }

    func testTrainingType_allHaveNonEmptyIcon() {
        for type in TrainingType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type) has empty icon")
        }
    }

    func testTrainingType_allHaveNonEmptyColor() {
        for type in TrainingType.allCases {
            XCTAssertFalse(type.color.isEmpty, "\(type) has empty color")
        }
    }

    // MARK: - DailyPlan.totalMinutes

    func testDailyPlan_totalMinutes_sumsTypes() {
        let plan = DailyPlan(
            dayOfWeek: "Monday", dayNumber: 1,
            trainingTypes: [.tactics, .openings],  // 15 + 20 = 35
            focusDescription: "Test", estimatedMinutes: 35
        )
        XCTAssertEqual(plan.totalMinutes, 35)
    }

    func testDailyPlan_totalMinutes_emptyIsZero() {
        let plan = DailyPlan(
            dayOfWeek: "Tuesday", dayNumber: 2,
            trainingTypes: [], focusDescription: "Rest", estimatedMinutes: 0
        )
        XCTAssertEqual(plan.totalMinutes, 0)
    }
}
