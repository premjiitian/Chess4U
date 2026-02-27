import XCTest
@testable import Chess4U

final class PersistenceServiceTests: XCTestCase {

    private let svc = PersistenceService.shared

    // Reset UserDefaults before and after each test so there is no cross-test pollution.
    override func setUp() {
        super.setUp()
        svc.resetAllData()
    }

    override func tearDown() {
        svc.resetAllData()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeProfile(elo: Int = 1200, name: String = "Alice") -> PlayerProfile {
        PlayerProfile(
            name: name, elo: elo,
            preferredTimeControl: .rapid, playerType: .casual,
            mainOpeningsWhite: ["e4"], mainDefensesBlack: ["e5"],
            ratingTrend: .improving, weaknesses: [.tactics]
        )
    }

    // MARK: - PlayerProfile

    func testLoadPlayerProfile_returnsNil_whenNothingSaved() {
        XCTAssertNil(svc.loadPlayerProfile())
    }

    func testSaveAndLoadPlayerProfile_roundTrip() {
        let profile = makeProfile(elo: 1350, name: "Bob")
        svc.savePlayerProfile(profile)
        let loaded = svc.loadPlayerProfile()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, "Bob")
        XCTAssertEqual(loaded?.elo, 1350)
        XCTAssertEqual(loaded?.ratingTrend, .improving)
    }

    // MARK: - AppSettings

    func testLoadSettings_returnsDefault_whenNothingSaved() {
        let s = svc.loadSettings()
        XCTAssertEqual(s.boardTheme, AppSettings().boardTheme)
        XCTAssertEqual(s.pieceStyle, AppSettings().pieceStyle)
    }

    func testSaveAndLoadSettings_roundTrip() {
        var settings = AppSettings()
        settings.boardTheme = .midnight
        settings.pieceStyle = .neo
        settings.soundEnabled = false
        svc.saveSettings(settings)
        let loaded = svc.loadSettings()
        XCTAssertEqual(loaded.boardTheme, .midnight)
        XCTAssertEqual(loaded.pieceStyle, .neo)
        XCTAssertFalse(loaded.soundEnabled)
    }

    // MARK: - Achievements

    func testLoadAchievements_returnsEmpty_whenNothingSaved() {
        XCTAssertTrue(svc.loadAchievements().isEmpty)
    }

    func testSaveAndLoadAchievements_roundTrip() {
        var a = Achievement.allAchievements.prefix(3).map { $0 }
        a[0].earnedDate = Date(timeIntervalSinceReferenceDate: 0)
        svc.saveAchievements(a)
        let loaded = svc.loadAchievements()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].id, a[0].id)
        XCTAssertNotNil(loaded[0].earnedDate)
    }

    // MARK: - Streak

    func testLoadStreak_returnsZero_whenNothingSaved() {
        XCTAssertEqual(svc.loadStreak(), 0)
    }

    func testSaveAndLoadStreak_sameDay_returnsValue() {
        svc.saveStreak(7)
        XCTAssertEqual(svc.loadStreak(), 7)
    }

    func testSaveStreak_overwritesPrevious() {
        svc.saveStreak(3)
        svc.saveStreak(10)
        XCTAssertEqual(svc.loadStreak(), 10)
    }

    // MARK: - Session history

    func testLoadSessionHistory_returnsEmpty_whenNothingSaved() {
        XCTAssertTrue(svc.loadSessionHistory().isEmpty)
    }

    func testSaveAndLoadSessionHistory_roundTrip() {
        let sessions = (0..<3).map { i in
            TrainingSession(type: .tactics, playerBand: .bandB,
                            startDate: Date(timeIntervalSinceReferenceDate: Double(i * 3600)))
        }
        svc.saveSessionHistory(sessions)
        let loaded = svc.loadSessionHistory()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].type, .tactics)
        XCTAssertEqual(loaded[0].playerBand, .bandB)
    }

    func testSaveSessionHistory_keepsOnlyLast100() {
        // Create 110 sessions — only the most recent 100 should be stored
        let sessions = (0..<110).map { i in
            TrainingSession(type: .endgame, playerBand: .bandA,
                            startDate: Date(timeIntervalSinceReferenceDate: Double(i)))
        }
        svc.saveSessionHistory(sessions)
        XCTAssertEqual(svc.loadSessionHistory().count, 100)
    }
}
