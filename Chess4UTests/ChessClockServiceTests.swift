import XCTest
@testable import Chess4U

final class ChessClockServiceTests: XCTestCase {

    private func makeClock(preset: ClockPreset = .blitz5) -> ChessClockService {
        let clock = ChessClockService()
        clock.configure(preset: preset)
        return clock
    }

    // MARK: - ClockPreset.initialSeconds

    func testPreset_bullet1_initialSeconds() {
        XCTAssertEqual(ClockPreset.bullet1.initialSeconds, 60)
    }

    func testPreset_bullet2_initialSeconds() {
        XCTAssertEqual(ClockPreset.bullet2.initialSeconds, 120)
    }

    func testPreset_blitz3_initialSeconds() {
        XCTAssertEqual(ClockPreset.blitz3.initialSeconds, 180)
    }

    func testPreset_blitz5_initialSeconds() {
        XCTAssertEqual(ClockPreset.blitz5.initialSeconds, 300)
    }

    func testPreset_rapid10_initialSeconds() {
        XCTAssertEqual(ClockPreset.rapid10.initialSeconds, 600)
    }

    func testPreset_rapid15_initialSeconds() {
        XCTAssertEqual(ClockPreset.rapid15.initialSeconds, 900)
    }

    func testPreset_classical_initialSeconds() {
        XCTAssertEqual(ClockPreset.classical.initialSeconds, 1800)
    }

    func testPreset_none_initialSeconds() {
        XCTAssertEqual(ClockPreset.none.initialSeconds, 0)
    }

    // MARK: - ClockPreset.incrementSeconds

    func testPreset_bullet2_incrementSeconds() {
        XCTAssertEqual(ClockPreset.bullet2.incrementSeconds, 1)
    }

    func testPreset_rapid15_incrementSeconds() {
        XCTAssertEqual(ClockPreset.rapid15.incrementSeconds, 10)
    }

    func testPreset_noIncrement_presetsHaveZeroIncrement() {
        let noIncrementPresets: [ClockPreset] = [.bullet1, .blitz3, .blitz5, .rapid10, .classical, .none]
        for preset in noIncrementPresets {
            XCTAssertEqual(preset.incrementSeconds, 0, "\(preset.rawValue) should have 0 increment")
        }
    }

    func testPreset_allCases_rawValueNonEmpty() {
        for preset in ClockPreset.allCases {
            XCTAssertFalse(preset.rawValue.isEmpty)
        }
    }

    // MARK: - configure()

    func testConfigure_setsWhiteTime() {
        let clock = makeClock(preset: .rapid10)
        XCTAssertEqual(clock.whiteTimeRemaining, 600, accuracy: 0.001)
    }

    func testConfigure_setsBlackTime() {
        let clock = makeClock(preset: .rapid10)
        XCTAssertEqual(clock.blackTimeRemaining, 600, accuracy: 0.001)
    }

    func testConfigure_setsActiveColorToWhite() {
        let clock = makeClock()
        XCTAssertEqual(clock.activeColor, .white)
    }

    func testConfigure_isNotRunning() {
        let clock = makeClock()
        XCTAssertFalse(clock.isRunning)
    }

    func testConfigure_isNotFlagged() {
        let clock = makeClock()
        XCTAssertFalse(clock.isFlagged)
    }

    // MARK: - start() / pause()

    func testStart_setsIsRunning() {
        let clock = makeClock(preset: .blitz5)
        clock.start()
        XCTAssertTrue(clock.isRunning)
    }

    func testStart_noClock_doesNotRun() {
        let clock = makeClock(preset: .none)
        clock.start()
        XCTAssertFalse(clock.isRunning)
    }

    func testPause_clearsIsRunning() {
        let clock = makeClock()
        clock.start()
        clock.pause()
        XCTAssertFalse(clock.isRunning)
    }

    // MARK: - pressClock() — switches sides and applies increment

    func testPressClock_switchesActiveColorToBlack() {
        let clock = makeClock(preset: .blitz5)
        clock.start()
        XCTAssertEqual(clock.activeColor, .white)
        clock.pressClock()
        XCTAssertEqual(clock.activeColor, .black)
    }

    func testPressClock_switchesActiveColorBackToWhite() {
        let clock = makeClock(preset: .blitz5)
        clock.start()
        clock.pressClock()   // white → black
        clock.pressClock()   // black → white
        XCTAssertEqual(clock.activeColor, .white)
    }

    func testPressClock_appliesIncrementToWhiteAfterMove() {
        // bullet2 gives 1s increment to the moving player
        let clock = makeClock(preset: .bullet2)
        clock.start()
        let before = clock.whiteTimeRemaining
        clock.pressClock()   // white moves → white gets +1s increment
        XCTAssertEqual(clock.whiteTimeRemaining, before + 1, accuracy: 0.001)
    }

    func testPressClock_appliesIncrementToBlackAfterMove() {
        let clock = makeClock(preset: .bullet2)
        clock.start()
        clock.pressClock()   // white → black
        let before = clock.blackTimeRemaining
        clock.pressClock()   // black moves → black gets +1s increment
        XCTAssertEqual(clock.blackTimeRemaining, before + 1, accuracy: 0.001)
    }

    func testPressClock_noIncrementPreset_timesUnchanged() {
        let clock = makeClock(preset: .blitz5)
        clock.start()
        let whiteBefore = clock.whiteTimeRemaining
        clock.pressClock()
        // No increment for blitz5 — white's time should be unchanged (timer hasn't fired)
        XCTAssertEqual(clock.whiteTimeRemaining, whiteBefore, accuracy: 0.001)
    }

    func testPressClock_whenNotRunning_doesNothing() {
        let clock = makeClock()
        // Not started — press should be ignored
        clock.pressClock()
        XCTAssertEqual(clock.activeColor, .white)
    }

    func testPressClock_whenFlagged_doesNothing() {
        let clock = makeClock()
        clock.start()
        clock.isFlagged = true
        clock.pressClock()
        XCTAssertEqual(clock.activeColor, .white)  // unchanged
    }

    // MARK: - reset()

    func testReset_restoresInitialTimes() {
        let clock = makeClock(preset: .blitz5)
        clock.start()
        clock.whiteTimeRemaining = 42
        clock.reset()
        XCTAssertEqual(clock.whiteTimeRemaining, 300, accuracy: 0.001)
        XCTAssertEqual(clock.blackTimeRemaining, 300, accuracy: 0.001)
    }

    func testReset_stopsRunning() {
        let clock = makeClock()
        clock.start()
        clock.reset()
        XCTAssertFalse(clock.isRunning)
    }

    func testReset_clearsFlagged() {
        let clock = makeClock()
        clock.isFlagged = true
        clock.reset()
        XCTAssertFalse(clock.isFlagged)
    }

    // MARK: - displayTime()

    func testDisplayTime_white_formatsCorrectly() {
        let clock = makeClock(preset: .blitz5)   // 300 s = 5:00
        XCTAssertEqual(clock.displayTime(for: .white), "5:00")
    }

    func testDisplayTime_black_formatsCorrectly() {
        let clock = makeClock(preset: .rapid10)   // 600 s = 10:00
        XCTAssertEqual(clock.displayTime(for: .black), "10:00")
    }

    func testDisplayTime_seconds_belowOneMinute() {
        let clock = makeClock(preset: .blitz5)
        clock.whiteTimeRemaining = 45
        XCTAssertEqual(clock.displayTime(for: .white), "0:45")
    }

    func testDisplayTime_singleDigitSeconds_zeroPadded() {
        let clock = makeClock(preset: .blitz5)
        clock.whiteTimeRemaining = 61   // 1:01
        XCTAssertEqual(clock.displayTime(for: .white), "1:01")
    }

    // MARK: - isLowTime()

    func testIsLowTime_bullet_threshold10s_flagsBelow() {
        // bullet1 = 60s initial → threshold = 10s
        let clock = makeClock(preset: .bullet1)
        clock.whiteTimeRemaining = 9
        XCTAssertTrue(clock.isLowTime(for: .white))
    }

    func testIsLowTime_bullet_threshold10s_notFlagsAt11s() {
        let clock = makeClock(preset: .bullet1)
        clock.whiteTimeRemaining = 11
        XCTAssertFalse(clock.isLowTime(for: .white))
    }

    func testIsLowTime_rapid_threshold30s_flagsBelow() {
        // rapid10 = 600s initial → threshold = 30s
        let clock = makeClock(preset: .rapid10)
        clock.blackTimeRemaining = 20
        XCTAssertTrue(clock.isLowTime(for: .black))
    }

    func testIsLowTime_rapid_threshold30s_notFlagsAt31s() {
        let clock = makeClock(preset: .rapid10)
        clock.blackTimeRemaining = 31
        XCTAssertFalse(clock.isLowTime(for: .black))
    }

    func testIsLowTime_zero_returnsFalse() {
        // Zero seconds remaining is flagged time, not "low" time
        let clock = makeClock(preset: .blitz5)
        clock.whiteTimeRemaining = 0
        XCTAssertFalse(clock.isLowTime(for: .white))
    }
}
