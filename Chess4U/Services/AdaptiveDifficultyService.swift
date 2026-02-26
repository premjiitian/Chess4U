import Foundation
import Combine

// MARK: - Adaptive Difficulty Service
final class AdaptiveDifficultyService: ObservableObject {
    static let shared = AdaptiveDifficultyService()
    private init() {}

    @Published var currentDifficulty: PuzzleDifficulty = .medium
    @Published var shouldShowHints: Bool = false
    @Published var shouldShowArrows: Bool = false
    @Published var difficultyMessage: String = ""

    private var recentResults: [Bool] = []  // true = correct, false = incorrect
    private var recentTimes: [TimeInterval] = []

    let successThreshold: Double = 0.80   // 80% success → increase difficulty
    let supportThreshold: Double = 0.50   // <50% success → provide support

    // MARK: - Record Result
    func recordResult(correct: Bool, timeSpent: TimeInterval) {
        recentResults.append(correct)
        recentTimes.append(timeSpent)

        // Keep last 10 results
        if recentResults.count > 10 {
            recentResults.removeFirst()
            recentTimes.removeFirst()
        }

        updateDifficulty()
    }

    private func updateDifficulty() {
        guard recentResults.count >= 5 else { return }

        let successRate = Double(recentResults.filter { $0 }.count) / Double(recentResults.count)

        if successRate > successThreshold {
            increaseDifficulty()
        } else if successRate < supportThreshold {
            decreaseDifficulty()
            enableSupport()
        } else {
            shouldShowHints = false
            shouldShowArrows = false
            difficultyMessage = ""
        }
    }

    private func increaseDifficulty() {
        let cases = PuzzleDifficulty.allCases
        if let idx = cases.firstIndex(of: currentDifficulty), idx < cases.count - 1 {
            currentDifficulty = cases[idx + 1]
            shouldShowHints = false
            shouldShowArrows = false
            difficultyMessage = "Great job! Difficulty increased to \(currentDifficulty.rawValue)."
        } else {
            difficultyMessage = "You're at maximum difficulty — excellent performance!"
        }
        recentResults = []
    }

    private func decreaseDifficulty() {
        let cases = PuzzleDifficulty.allCases
        if let idx = cases.firstIndex(of: currentDifficulty), idx > 0 {
            currentDifficulty = cases[idx - 1]
            difficultyMessage = "Let's build confidence at \(currentDifficulty.rawValue) level."
        }
        recentResults = []
    }

    private func enableSupport() {
        shouldShowHints = true
        shouldShowArrows = true
    }

    // MARK: - Get Recommended Settings for Profile
    func recommendedSettings(for profile: PlayerProfile) -> DifficultySettings {
        switch profile.band {
        case .bandA:
            return DifficultySettings(
                puzzleDifficulty: .beginner,
                showHints: true,
                showArrows: true,
                showEvalBar: false,
                calculationDepth: 2,
                timePerMove: 120
            )
        case .bandB:
            return DifficultySettings(
                puzzleDifficulty: .easy,
                showHints: true,
                showArrows: false,
                showEvalBar: false,
                calculationDepth: 3,
                timePerMove: 90
            )
        case .bandC:
            return DifficultySettings(
                puzzleDifficulty: .medium,
                showHints: false,
                showArrows: false,
                showEvalBar: true,
                calculationDepth: 5,
                timePerMove: 60
            )
        case .bandD:
            return DifficultySettings(
                puzzleDifficulty: .hard,
                showHints: false,
                showArrows: false,
                showEvalBar: true,
                calculationDepth: 8,
                timePerMove: 45
            )
        case .bandE:
            return DifficultySettings(
                puzzleDifficulty: .expert,
                showHints: false,
                showArrows: false,
                showEvalBar: true,
                calculationDepth: 12,
                timePerMove: 30
            )
        }
    }

    var successRate: Double {
        guard !recentResults.isEmpty else { return 0 }
        return Double(recentResults.filter { $0 }.count) / Double(recentResults.count)
    }

    var averageTime: TimeInterval {
        guard !recentTimes.isEmpty else { return 0 }
        return recentTimes.reduce(0, +) / Double(recentTimes.count)
    }
}

// MARK: - Difficulty Settings
struct DifficultySettings {
    var puzzleDifficulty: PuzzleDifficulty
    var showHints: Bool
    var showArrows: Bool
    var showEvalBar: Bool
    var calculationDepth: Int
    var timePerMove: Int   // seconds
}
