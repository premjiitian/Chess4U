import XCTest

@MainActor
final class Chess4UUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["--uitesting"]
        app.launch()
    }

    func testTakeScreenshots() throws {
        // Walk through onboarding if it's showing
        if app.buttons["Get Started"].waitForExistence(timeout: 4) {
            app.buttons["Get Started"].tap()
        }
        // Pick skill level on assessment screen
        let bandB = app.buttons["Band B (1000–1300)"]
        if bandB.waitForExistence(timeout: 4) {
            bandB.tap()
        }
        // Fill in name if present
        let nameField = app.textFields.firstMatch
        if nameField.waitForExistence(timeout: 2) {
            nameField.tap()
            nameField.typeText("Alex")
            app.keyboards.buttons["Done"].tapIfExists()
        }
        // Confirm assessment
        for label in ["Start Training", "Continue", "Done"] {
            let btn = app.buttons[label]
            if btn.waitForExistence(timeout: 2) { btn.tap(); break }
        }

        // Wait for main tab bar to appear
        let tabBar = app.tabBars.firstMatch
        XCTAssert(tabBar.waitForExistence(timeout: 8))

        // 1 — Dashboard
        snapshot("01_Dashboard")

        // 2 — Training Hub
        tabBar.buttons.element(boundBy: 1).tap()
        sleep(1)
        snapshot("02_TrainingHub")

        // 3 — Chess Board
        tabBar.buttons.element(boundBy: 2).tap()
        sleep(1)
        snapshot("03_Board")

        // 4 — Profile
        tabBar.buttons.element(boundBy: 3).tap()
        sleep(1)
        snapshot("04_Profile")
    }
}

private extension XCUIElement {
    func tapIfExists() {
        if exists { tap() }
    }
}
