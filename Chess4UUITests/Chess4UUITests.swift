import XCTest

@MainActor
final class Chess4UUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Seed realistic mock data so screenshots show an active user, not empty state
        app.launchArguments += ["-SCREENSHOT_MODE"]
        setupSnapshot(app)
        app.launch()
    }

    func testTakeScreenshots() throws {
        // ── Skip onboarding — mock data seeds a complete profile ─────────────
        // Wait for main tab view to appear directly (profile is pre-seeded)
        let tabBar = app.tabBars.firstMatch
        XCTAssert(tabBar.waitForExistence(timeout: 15), "Tab bar not found after mock data seed")

        // ── Capture screenshots ───────────────────────────────────────────────
        // 1 — Dashboard
        snapshot("01_Dashboard")

        // 2 — Train
        tabBar.buttons.element(boundBy: 1).tap()
        sleep(1)
        snapshot("02_TrainingHub")

        // 3 — Board
        tabBar.buttons.element(boundBy: 2).tap()
        sleep(1)
        snapshot("03_Board")

        // 4 — Lessons
        tabBar.buttons.element(boundBy: 3).tap()
        sleep(1)
        snapshot("04_Lessons")

        // 5 — Profile
        tabBar.buttons.element(boundBy: 4).tap()
        sleep(1)
        snapshot("05_Profile")
    }

    // MARK: - Helpers

    private func tapButton(_ label: String, timeout: TimeInterval = 10) {
        let btn = app.buttons[label]
        if btn.waitForExistence(timeout: timeout) { btn.tap() }
    }
}
