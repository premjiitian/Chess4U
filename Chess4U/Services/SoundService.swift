import AVFoundation
import UIKit

// MARK: - Sound Service
/// Plays chess-themed sound effects using system AudioServicesPlaySystemSound.
/// Sounds fire even when the device is on silent if the setting is on (UIKit default),
/// so we respect the user's `soundEnabled` preference via AppSettings.
final class SoundService {
    static let shared = SoundService()

    // System sound IDs for approximate chess feedback.
    // These are built-in iOS system sounds — no audio asset files required.
    private enum SystemSoundID: UInt32 {
        case tap       = 1104  // light tap — quiet move
        case lock      = 1100  // heavier click — capture
        case triTone   = 1016  // alert triple — check
        case photoShot = 1108  // camera click — castling
        case success   = 1025  // positive — promotion / game won
        case error     = 1053  // negative — game lost
    }

    var isEnabled: Bool = true

    private init() {}

    func playMove() {
        guard isEnabled else { return }
        play(.tap)
    }

    func playCapture() {
        guard isEnabled else { return }
        play(.lock)
    }

    func playCheck() {
        guard isEnabled else { return }
        play(.triTone)
    }

    func playCastling() {
        guard isEnabled else { return }
        play(.photoShot)
    }

    func playPromotion() {
        guard isEnabled else { return }
        play(.success)
    }

    func playGameWon() {
        guard isEnabled else { return }
        play(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.play(.success) }
    }

    func playGameLost() {
        guard isEnabled else { return }
        play(.error)
    }

    func playIllegalMove() {
        guard isEnabled else { return }
        // Short vibrate to signal invalid tap
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    func playPuzzleSolved() {
        guard isEnabled else { return }
        play(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.play(.success) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.play(.success) }
    }

    // MARK: - Private

    private func play(_ sound: SystemSoundID) {
        AudioServicesPlaySystemSound(sound.rawValue)
    }
}
