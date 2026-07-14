import SwiftUI

// MARK: - App Theme
/// Chess4U's design system. Palette takes cues from chess.com (a confident,
/// signature green as the single brand accent instead of generic iOS blue)
/// and Chessable (clean white/light cards, one warm highlight color reserved
/// for streaks, gamification and calls to attention). Every screen should
/// pull colors from here rather than hard-coding `.blue` / `.purple` / etc.,
/// so the app reads as one cohesive product rather than a patchwork of
/// default SwiftUI tints.
struct AppTheme {
    /// Primary brand color — used for the tab bar, primary buttons, links,
    /// and anything that represents the "main action" on screen.
    static let accent = Color(red: 0.29, green: 0.47, blue: 0.24)       // deep chess green
    static let accentLight = Color(red: 0.29, green: 0.47, blue: 0.24).opacity(0.12)

    /// Secondary brand color — reserved for streaks, badges, daily puzzle,
    /// and other "come back today" gamification moments (Chessable-style).
    static let highlight = Color(red: 0.93, green: 0.58, blue: 0.20)    // warm amber
    static let highlightLight = Color(red: 0.93, green: 0.58, blue: 0.20).opacity(0.12)

    /// Semantic colors — feedback only, not decoration. Keep these for
    /// success/warning/danger states so they stay meaningful.
    static let success = Color(red: 0.30, green: 0.62, blue: 0.35)
    static let warning = Color(red: 0.93, green: 0.58, blue: 0.20)
    static let danger = Color(red: 0.80, green: 0.28, blue: 0.27)

    static let background = Color(.systemGroupedBackground)
    static let cardBackground = Color(.systemBackground)

    // MARK: Layout constants — keep every card visually consistent
    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let cardShadow = Color.black.opacity(0.06)

    // Board colors (default "classic" theme — see BoardTheme for the rest)
    static let lightSquare = Color(red: 0.95, green: 0.92, blue: 0.82)
    static let darkSquare = Color(red: 0.46, green: 0.59, blue: 0.34)
    static let selectedSquare = Color.yellow.opacity(0.7)
    static let legalMove = Color.blue.opacity(0.35)
    static let lastMove = Color.yellow.opacity(0.4)
}

extension View {
    /// Standard elevated card look used across Dashboard, Training, and Analysis
    /// screens — swap in for ad-hoc `.background(...).cornerRadius(...)` calls
    /// so every card shares the same corner radius and a subtle shadow instead
    /// of a hard 1px system background edge.
    func chessCard() -> some View {
        self
            .padding(AppTheme.cardPadding)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cardCornerRadius)
            .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 2)
    }
}

extension Color {
    static let chessBrown = Color(red: 0.72, green: 0.53, blue: 0.33)
    static let chessGreen = Color(red: 0.46, green: 0.59, blue: 0.34)
    static let chessCream = Color(red: 0.95, green: 0.92, blue: 0.82)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
