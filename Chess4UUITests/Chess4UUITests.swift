import XCTest

@MainActor
final class Chess4UUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    func testTakeScreenshots() throws {
        // ── Onboarding (4 pages) ─────────────────────────────────────────────
        // Pages 0-2: tap "Next"
        for _ in 0..<3 {
            let next = app.buttons["Next"]
            if next.waitForExistence(timeout: 4) { next.tap() }
        }
        // Page 3: tap "Start My Training Journey"
        let startJourney = app.buttons["Start My Training Journey"]
        if startJourney.waitForExistence(timeout: 4) { startJourney.tap() }

        // ── Player Assessment (4 steps) ───────────────────────────────────────
        // Step 0 (Basic Info): type a name, then Continue
        let nameField = app.textFields.firstMatch
        if nameField.waitForExistence(timeout: 3) {
            nameField.tap()
            nameField.typeText("Alex")
        }
        tapButton("Continue")

        // Step 1 (Play Style): Continue
        tapButton("Continue")

        // Step 2 (Weaknesses): Continue
        tapButton("Continue")

        // Step 3 (Openings): Start Training!
        tapButton("Start Training!")

        // ── Capture screenshots ───────────────────────────────────────────────
        let tabBar = app.tabBars.firstMatch
        XCTAssert(tabBar.waitForExistence(timeout: 10), "Tab bar not found after onboarding")

        // 1 — Dashboard (initial tab)
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

    private func tapButton(_ label: String, timeout: TimeInterval = 4) {
        let btn = app.buttons[label]
        if btn.waitForExistence(timeout: timeout) { btn.tap() }
    }
}
