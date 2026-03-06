import Foundation
import Combine

// MARK: - Time Control Preset
enum ClockPreset: String, CaseIterable {
    case bullet1  = "1 min"
    case bullet2  = "2+1"
    case blitz3   = "3 min"
    case blitz5   = "5 min"
    case rapid10  = "10 min"
    case rapid15  = "15+10"
    case classical = "30 min"
    case none     = "No Clock"

    var initialSeconds: TimeInterval {
        switch self {
        case .bullet1:   return 60
        case .bullet2:   return 120
        case .blitz3:    return 180
        case .blitz5:    return 300
        case .rapid10:   return 600
        case .rapid15:   return 900
        case .classical: return 1800
        case .none:      return 0
        }
    }

    var incrementSeconds: TimeInterval {
        switch self {
        case .bullet2:  return 1
        case .rapid15:  return 10
        default:        return 0
        }
    }
}

// MARK: - Chess Clock Service
final class ChessClockService: ObservableObject {
    @Published var whiteTimeRemaining: TimeInterval = 300
    @Published var blackTimeRemaining: TimeInterval = 300
    @Published var activeColor: PieceColor = .white
    @Published var isRunning: Bool = false
    @Published var isFlagged: Bool = false   // true when a player runs out of time

    private var timer: AnyCancellable?
    private var increment: TimeInterval = 0
    private var preset: ClockPreset = .blitz5

    // MARK: - Setup
    func configure(preset: ClockPreset) {
        self.preset = preset
        self.increment = preset.incrementSeconds
        whiteTimeRemaining = preset.initialSeconds
        blackTimeRemaining = preset.initialSeconds
        activeColor = .white
        isRunning = false
        isFlagged = false
        stopTimer()
    }

    // MARK: - Control
    func start() {
        guard preset != .none, !isFlagged else { return }
        isRunning = true
        startTimer()
    }

    func pause() {
        isRunning = false
        stopTimer()
    }

    func pressClock() {
        guard isRunning, !isFlagged else { return }
        // Add increment to the player who just moved
        if activeColor == .white {
            whiteTimeRemaining += increment
            activeColor = .black
        } else {
            blackTimeRemaining += increment
            activeColor = .white
        }
    }

    func reset() {
        configure(preset: preset)
    }

    // MARK: - Formatting
    func displayTime(for color: PieceColor) -> String {
        let secs = color == .white ? whiteTimeRemaining : blackTimeRemaining
        return formatTime(secs)
    }

    func isLowTime(for color: PieceColor) -> Bool {
        let secs = color == .white ? whiteTimeRemaining : blackTimeRemaining
        let threshold: TimeInterval = preset.initialSeconds <= 120 ? 10 : 30
        return secs <= threshold && secs > 0
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let s = max(0, seconds)
        let m = Int(s) / 60
        let sec = Int(s) % 60
        if m >= 60 {
            return String(format: "%d:%02d:00", m / 60, m % 60)
        }
        return String(format: "%d:%02d", m, sec)
    }

    // MARK: - Timer
    private func startTimer() {
        stopTimer()
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        guard isRunning, !isFlagged else { return }
        if activeColor == .white {
            whiteTimeRemaining = max(0, whiteTimeRemaining - 0.1)
            if whiteTimeRemaining == 0 {
                isFlagged = true
                isRunning = false
                stopTimer()
            }
        } else {
            blackTimeRemaining = max(0, blackTimeRemaining - 0.1)
            if blackTimeRemaining == 0 {
                isFlagged = true
                isRunning = false
                stopTimer()
            }
        }
    }
}
