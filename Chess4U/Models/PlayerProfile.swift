import Foundation

// MARK: - Player Band
enum PlayerBand: String, Codable, CaseIterable {
    case bandA = "Band A (800–1000)"
    case bandB = "Band B (1000–1300)"
    case bandC = "Band C (1300–1600)"
    case bandD = "Band D (1600–1800)"
    case bandE = "Band E (1800–2000)"

    static func band(for elo: Int) -> PlayerBand {
        switch elo {
        case ..<1000: return .bandA
        case 1000..<1300: return .bandB
        case 1300..<1600: return .bandC
        case 1600..<1800: return .bandD
        default: return .bandE
        }
    }

    var focusAreas: [String] {
        switch self {
        case .bandA: return ["Blunder prevention", "Board vision", "Basic tactics", "Opening principles"]
        case .bandB: return ["Tactical patterns", "Development advantage", "Basic endgames", "Simple plans"]
        case .bandC: return ["Calculation discipline", "Pawn structures", "Attacking patterns", "Positional mistakes"]
        case .bandD: return ["Strategic planning", "Piece coordination", "Advanced tactics", "Endgame transitions"]
        case .bandE: return ["Deep calculation", "Prophylaxis", "Imbalances", "Master-level planning", "Conversion technique"]
        }
    }

    var calculationDepth: ClosedRange<Int> {
        switch self {
        case .bandA: return 2...3
        case .bandB: return 3...5
        case .bandC: return 5...8
        case .bandD: return 5...8
        case .bandE: return 8...15
        }
    }

    var icon: String {
        switch self {
        case .bandA: return "🌱"
        case .bandB: return "🌿"
        case .bandC: return "🌳"
        case .bandD: return "⚔️"
        case .bandE: return "👑"
        }
    }
}

// MARK: - Time Control
enum TimeControl: String, Codable, CaseIterable {
    case bullet = "Bullet (1-2 min)"
    case blitz = "Blitz (3-5 min)"
    case rapid = "Rapid (10-15 min)"
    case classical = "Classical (30+ min)"
}

// MARK: - Player Type
enum PlayerType: String, Codable, CaseIterable {
    case tournament = "Tournament"
    case casual = "Casual"
}

// MARK: - Rating Trend
enum RatingTrend: String, Codable, CaseIterable {
    case improving = "Improving"
    case stable = "Stable"
    case declining = "Declining"
}

// MARK: - Weakness Area
enum WeaknessArea: String, Codable, CaseIterable, Hashable {
    case blunders = "Blunders"
    case tactics = "Tactics"
    case strategy = "Strategy"
    case endgames = "Endgames"
    case openings = "Openings"
    case calculation = "Calculation"
    case timeManagement = "Time Management"

    var icon: String {
        switch self {
        case .blunders: return "exclamationmark.triangle"
        case .tactics: return "bolt"
        case .strategy: return "map"
        case .endgames: return "flag.checkered"
        case .openings: return "book"
        case .calculation: return "brain"
        case .timeManagement: return "clock"
        }
    }
}

// MARK: - Player Profile
struct PlayerProfile: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var elo: Int
    var preferredTimeControl: TimeControl
    var playerType: PlayerType
    var mainOpeningsWhite: [String]
    var mainDefensesBlack: [String]
    var ratingTrend: RatingTrend
    var weaknesses: [WeaknessArea]
    var createdAt: Date = Date()
    var lastSessionDate: Date?
    var sessionsCompleted: Int = 0
    var totalPuzzlesSolved: Int = 0
    var tacticsAccuracy: Double = 0.0
    var openingAccuracy: Double = 0.0
    var endgameAccuracy: Double = 0.0
    var calculationScore: Double = 0.0
    var strategyScore: Double = 0.0

    var band: PlayerBand { PlayerBand.band(for: elo) }

    var skillScores: [String: Double] {
        [
            "Tactics": tacticsAccuracy,
            "Openings": openingAccuracy,
            "Endgames": endgameAccuracy,
            "Calculation": calculationScore,
            "Strategy": strategyScore
        ]
    }

    mutating func updateElo(_ newElo: Int) {
        elo = newElo
    }

    mutating func updateAccuracy(tactics: Double? = nil, opening: Double? = nil,
                                  endgame: Double? = nil, calculation: Double? = nil,
                                  strategy: Double? = nil) {
        if let t = tactics { tacticsAccuracy = (tacticsAccuracy + t) / 2.0 }
        if let o = opening { openingAccuracy = (openingAccuracy + o) / 2.0 }
        if let e = endgame { endgameAccuracy = (endgameAccuracy + e) / 2.0 }
        if let c = calculation { calculationScore = (calculationScore + c) / 2.0 }
        if let s = strategy { strategyScore = (strategyScore + s) / 2.0 }
    }
}

// MARK: - App Settings
struct AppSettings: Codable {
    var uiMode: UIMode = .study
    var boardTheme: BoardTheme = .classic
    var pieceStyle: PieceStyle = .standard
    var colorThemeName: String = "default"
    var animationsEnabled: Bool = true
    var soundEnabled: Bool = true
    var hintLevel: HintLevel = .medium
    var audioCoachEnabled: Bool = true
    var showCoordinates: Bool = true
    var autoFlipBoard: Bool = true

    var colorScheme: ColorScheme? {
        switch colorThemeName {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
}

enum UIMode: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case tournament = "Tournament"
    case study = "Study"
    case kids = "Kids"
    case focus = "Focus"

    var description: String {
        switch self {
        case .beginner: return "Large board, hints, visual guides"
        case .tournament: return "Minimal UI, no hints, clock pressure"
        case .study: return "Analysis board, variation tree, coach notes"
        case .kids: return "Gamified interface, rewards, short lessons"
        case .focus: return "Distraction-free environment"
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "hand.raised"
        case .tournament: return "trophy"
        case .study: return "books.vertical"
        case .kids: return "star"
        case .focus: return "eye"
        }
    }
}

enum BoardTheme: String, Codable, CaseIterable {
    case classic = "Classic"
    case wood = "Wood"
    case marble = "Marble"
    case midnight = "Midnight"
    case tournament = "Tournament"
    case coral = "Coral"
}

enum PieceStyle: String, Codable, CaseIterable {
    case standard = "Standard"
    case neo = "Neo"
    case alpha = "Alpha"
    case merida = "Merida"
}

enum HintLevel: String, Codable, CaseIterable {
    case none = "None"
    case minimal = "Minimal"
    case medium = "Medium"
    case full = "Full"
}
