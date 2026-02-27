import XCTest
@testable import Chess4U

final class TreeOfThoughtEngineTests: XCTestCase {

    private let engine = TreeOfThoughtEngine.shared

    private func makeProfile(
        elo: Int = 1200,
        weaknesses: [WeaknessArea] = [],
        tactics: Double = 50, openings: Double = 50,
        endgames: Double = 50, calculation: Double = 50, strategy: Double = 50
    ) -> PlayerProfile {
        var p = PlayerProfile(
            name: "Test", elo: elo,
            preferredTimeControl: .rapid, playerType: .casual,
            mainOpeningsWhite: [], mainDefensesBlack: [],
            ratingTrend: .stable, weaknesses: weaknesses
        )
        p.tacticsAccuracy  = tactics
        p.openingAccuracy  = openings
        p.endgameAccuracy  = endgames
        p.calculationScore = calculation
        p.strategyScore    = strategy
        return p
    }

    // MARK: - generateWeeklyPlan

    func testGenerateWeeklyPlan_returns7Days() {
        for band in PlayerBand.allCases {
            let profile = makeProfile(elo: [900, 1100, 1400, 1700, 2000][PlayerBand.allCases.firstIndex(of: band)!])
            let plan = engine.generateWeeklyPlan(for: profile)
            XCTAssertEqual(plan.count, 7, "\(band) weekly plan should have 7 days")
        }
    }

    func testGenerateWeeklyPlan_eachDayHasAtLeastOneType() {
        let plan = engine.generateWeeklyPlan(for: makeProfile())
        for day in plan {
            XCTAssertFalse(day.trainingTypes.isEmpty, "\(day.dayOfWeek) has no training types")
        }
    }

    func testGenerateWeeklyPlan_estimatedMinutesMatchesTypes() {
        let plan = engine.generateWeeklyPlan(for: makeProfile())
        for day in plan {
            let expected = day.trainingTypes.reduce(0) { $0 + $1.estimatedMinutes }
            XCTAssertEqual(day.estimatedMinutes, expected,
                "\(day.dayOfWeek) estimatedMinutes doesn't match sum of types")
        }
    }

    // MARK: - selectTrainingPath

    func testSelectTrainingPath_returnsAValidType() {
        let result = engine.selectTrainingPath(for: makeProfile(), sessionHistory: [])
        XCTAssertTrue(TrainingType.allCases.contains(result))
    }

    func testSelectTrainingPath_prefersWeaknessArea() {
        // Profile with very low tactics accuracy and explicit tactics weakness
        let profile = makeProfile(weaknesses: [.tactics, .blunders], tactics: 10)
        let result = engine.selectTrainingPath(for: profile, sessionHistory: [])
        // Tactics or blunderReduction should score highest given the heavy bonus
        XCTAssertTrue(result == .tactics || result == .blunderReduction,
            "Expected tactics or blunderReduction, got \(result)")
    }

    func testSelectTrainingPath_avoidsRecentRepetition() {
        // If the last 3 sessions were all tactics, the score for tactics is penalised
        let profile = makeProfile()
        let recentSessions = (0..<3).map { _ in
            TrainingSession(type: .tactics, playerBand: .bandB, startDate: Date())
        }
        let result = engine.selectTrainingPath(for: profile, sessionHistory: recentSessions)
        // Tactics should be deprioritised (–45 penalty), another type should win
        XCTAssertNotEqual(result, .tactics, "Should avoid repeating tactics 4 times in a row")
    }

    // MARK: - blunderCheckQuestions

    func testBlunderCheckQuestions_atLeastFourAlways() {
        let board = ChessBoard()
        let questions = engine.blunderCheckQuestions(for: board)
        XCTAssertGreaterThanOrEqual(questions.count, 4)
    }

    func testBlunderCheckQuestions_moreWhenInCheck() {
        // Fool's-mate position (white in check): board after 1.f3 e5 2.g4 Qh4#
        let fen = "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3"
        guard let board = ChessBoard(fen: fen) else { XCTFail("FEN failed"); return }
        let qStarting = engine.blunderCheckQuestions(for: ChessBoard()).count
        let qCheck    = engine.blunderCheckQuestions(for: board).count
        XCTAssertGreaterThan(qCheck, qStarting, "In-check position should yield extra question")
    }

    func testBlunderCheckQuestions_allNonEmpty() {
        for q in engine.blunderCheckQuestions(for: ChessBoard()) {
            XCTAssertFalse(q.isEmpty)
        }
    }

    // MARK: - generateSession

    func testGenerateSession_typeMatchesRequest() {
        let session = engine.generateSession(type: .tactics, profile: makeProfile())
        XCTAssertEqual(session.type, .tactics)
    }

    func testGenerateSession_hasConceptLesson() {
        let session = engine.generateSession(type: .endgame, profile: makeProfile())
        XCTAssertNotNil(session.conceptLesson)
    }

    // MARK: - MoveQuality

    func testMoveQuality_bestIcon()    { XCTAssertEqual(MoveQuality.best.icon,       "!!") }
    func testMoveQuality_blunderIcon() { XCTAssertEqual(MoveQuality.blunder.icon,    "??") }
    func testMoveQuality_allHaveNonEmptyIcon() {
        for q in [MoveQuality.best, .good, .acceptable, .inaccuracy, .mistake, .blunder] {
            XCTAssertFalse(q.icon.isEmpty)
        }
    }

    func testMoveQuality_bestGoodAreGreen() {
        XCTAssertEqual(MoveQuality.best.color, "green")
        XCTAssertEqual(MoveQuality.good.color, "green")
    }

    func testMoveQuality_blunderIsRed() {
        XCTAssertEqual(MoveQuality.blunder.color, "red")
    }

    func testMoveQuality_acceptableIsBlue() {
        XCTAssertEqual(MoveQuality.acceptable.color, "blue")
    }

    // MARK: - CoachInsight defaults

    func testCoachInsight_defaultQualityIsAcceptable() {
        XCTAssertEqual(CoachInsight().moveQuality, .acceptable)
    }

    func testCoachInsight_qualityIconMatchesMoveQuality() {
        var insight = CoachInsight()
        insight.moveQuality = .blunder
        XCTAssertEqual(insight.qualityIcon, MoveQuality.blunder.icon)
    }
}
