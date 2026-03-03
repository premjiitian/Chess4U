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
        // ── Wait for main navigation to appear ───────────────────────────────
        // On iPhone: TabView renders a tab bar at the bottom.
        // On iPad (iOS 18): TabView may render an adaptive sidebar or top tab
        // bar instead, so `tabBars` can be empty on regular-size iPad.
        let tabBar = app.tabBars.firstMatch
        let dashboardAny = app.buttons
            .matching(NSPredicate(format: "label CONTAINS 'Dashboard'"))
            .firstMatch

        let navAppeared = tabBar.waitForExistence(timeout: 15)
            || dashboardAny.waitForExistence(timeout: 5)
        XCTAssert(navAppeared, "Main navigation not found — onboarding may not have been skipped")

        // ── Capture screenshots ───────────────────────────────────────────────
        // 1 — Dashboard (already on this tab)
        snapshot("01_Dashboard")

        // 2 — Train
        navigateTo("Train")
        sleep(1)
        snapshot("02_TrainingHub")

        // 3 — Board
        navigateTo("Board")
        sleep(1)
        snapshot("03_Board")

        // 4 — Lessons
        navigateTo("Lessons")
        sleep(1)
        snapshot("04_Lessons")

        // 5 — Profile
        navigateTo("Profile")
        sleep(1)
        snapshot("05_Profile")
    }

    // MARK: - Helpers

    /// Navigate to a tab by label. Handles:
    ///  - iPhone tab bars (`tabBars.buttons["Label"]`)
    ///  - iPad adaptive sidebars / top bars (any button whose label contains the text)
    ///  - Toolbar items as a last resort
    private func navigateTo(_ label: String) {
        // Tab bar (iPhone, compact iPad)
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let btn = tabBar.buttons[label]
            if btn.waitForExistence(timeout: 3) { btn.tap(); return }
        }

        // Sidebar / adaptive tab bar (regular-size iPad, iOS 18+)
        let sidebarBtn = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", label))
            .firstMatch
        if sidebarBtn.waitForExistence(timeout: 3) { sidebarBtn.tap(); return }

        // Toolbar fallback
        let toolbarBtn = app.toolbars.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", label))
            .firstMatch
        if toolbarBtn.waitForExistence(timeout: 3) { toolbarBtn.tap() }
    }
}
