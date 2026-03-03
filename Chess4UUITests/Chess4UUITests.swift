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
        // ── Wait for the app's main UI to appear ─────────────────────────────
        // On iPhone: TabView shows a classic bottom tab bar.
        // On iPad iOS 18: TabView may show an adaptive top tab bar or sidebar.
        //   • app.tabBars may still exist but button labels can include
        //     trailing ", tab, N of M" text  →  exact match fails.
        //   • The sidebar variant uses table cells, not buttons.
        //   • Don't hard-assert here — take whatever screenshots are available
        //     so the job never exits with zero iPad screenshots.
        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 15)

        // Give the Dashboard content extra time to render (iPad is bigger)
        sleep(2)

        // ── Capture screenshots ───────────────────────────────────────────────
        // 1 — Dashboard (already on this tab)
        snapshot("01_Dashboard")

        // 2 — Train
        navigateTo("Train")
        sleep(2)
        snapshot("02_TrainingHub")

        // 3 — Board
        navigateTo("Board")
        sleep(2)
        snapshot("03_Board")

        // 4 — Lessons
        navigateTo("Lessons")
        sleep(2)
        snapshot("04_Lessons")

        // 5 — Profile
        navigateTo("Profile")
        sleep(2)
        snapshot("05_Profile")
    }

    // MARK: - Helpers

    /// Navigate to a named tab, covering all iOS 18 iPad layout variants:
    ///  1. Classic bottom tab bar (iPhone, compact-width iPad)
    ///  2. Adaptive top tab bar on iPad — buttons may include ", tab, N of M"
    ///  3. Sidebar on iPad — items are UITableViewCell / XCUIElementTypeCell
    private func navigateTo(_ label: String) {
        let id = "tab_\(label.lowercased())"

        // ── 1. Tab bar: try exact label then CONTAINS (iOS 18 appends metadata)
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let exactBtn = tabBar.buttons[label]
            if exactBtn.exists { exactBtn.tap(); return }

            let containsBtn = tabBar.buttons
                .matching(NSPredicate(format: "label CONTAINS[c] %@", label))
                .firstMatch
            if containsBtn.waitForExistence(timeout: 3) { containsBtn.tap(); return }
        }

        // ── 2. Accessibility identifier (set via .accessibilityIdentifier on tab content)
        let idElement = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", id))
            .firstMatch
        if idElement.waitForExistence(timeout: 3) { idElement.tap(); return }

        // ── 3. Any button anywhere whose label contains the tab name
        let anyBtn = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", label))
            .firstMatch
        if anyBtn.waitForExistence(timeout: 3) { anyBtn.tap(); return }

        // ── 4. Sidebar table cell (iOS 18 regular-size iPad sidebar)
        let cell = app.cells
            .matching(NSPredicate(format: "label CONTAINS[c] %@", label))
            .firstMatch
        if cell.waitForExistence(timeout: 3) { cell.tap(); return }

        // ── 5. Static text as last resort (some sidebar implementations)
        let txt = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", label))
            .firstMatch
        if txt.waitForExistence(timeout: 3) { txt.tap() }
    }
}
