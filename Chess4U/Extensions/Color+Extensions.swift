import SwiftUI

// MARK: - App Theme
struct AppTheme {
    static let accent = Color.blue
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red

    static let background = Color(.systemGroupedBackground)
    static let cardBackground = Color(.systemBackground)

    // Board colors
    static let lightSquare = Color(red: 0.95, green: 0.92, blue: 0.82)
    static let darkSquare = Color(red: 0.46, green: 0.59, blue: 0.34)
    static let selectedSquare = Color.yellow.opacity(0.7)
    static let legalMove = Color.blue.opacity(0.35)
    static let lastMove = Color.yellow.opacity(0.4)
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
