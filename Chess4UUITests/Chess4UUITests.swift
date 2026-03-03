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
        // Pages 0–2: tap "Next"
        for _ in 0..<3 {
            let next = app.buttons["Next"]
            if next.waitForExistence(timeout: 10) { next.tap() }
        }
        // Page 3: tap "Start My Training Journey"
        let startJourney = app.buttons["Start My Training Journey"]
        if startJourney.waitForExistence(timeout: 10) { startJourney.tap() }

        // ── Player Assessment (4 steps) ───────────────────────────────────────
        // Step 0 (Basic Info): find name field by placeholder, type name, Continue.
        // isCurrentStepValid requires playerName non-empty AND valid Elo (default "1200" ✓).
        let nameField = app.textFields["Your name"]
        if nameField.waitForExistence(timeout: 10) {
            nameField.tap()
            nameField.typeText("Alex")
        }
        tapButton("Continue")

        // Step 1 (Play Style): always valid — just Continue
        tapButton("Continue")

        // Step 2 (Weaknesses): isCurrentStepValid requires ≥1 weakness selected.
        // Tap "Tactics" (label may include SF Symbol name, so use CONTAINS predicate).
        let weaknessBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Tactics'")
        ).firstMatch
        if weaknessBtn.waitForExistence(timeout: 10) { weaknessBtn.tap() }
        tapButton("Continue")

        // Step 3 (Openings): always valid — tap "Start Training!"
        tapButton("Start Training!")

        // ── Wait for main tab view ────────────────────────────────────────────
        let tabBar = app.tabBars.firstMatch
        XCTAssert(tabBar.waitForExistence(timeout: 15), "Tab bar not found after onboarding")

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
