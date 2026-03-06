import UIKit
import CoreHaptics

// MARK: - Haptic Service
/// Provides context-aware haptic feedback for all chess board interactions.
/// Uses UIImpactFeedbackGenerator for broad device support, with CoreHaptics
/// patterns on devices that support it for richer chess-specific sensations.
final class HapticService {
    static let shared = HapticService()

    private var engine: CHHapticEngine?
    private let moveGenerator    = UIImpactFeedbackGenerator(style: .light)
    private let captureGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let checkGenerator   = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {
        prepareGenerators()
        startCoreHapticsEngine()
    }

    // MARK: - Prepare

    private func prepareGenerators() {
        moveGenerator.prepare()
        captureGenerator.prepare()
        checkGenerator.prepare()
        selectionGenerator.prepare()
    }

    private func startCoreHapticsEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
        } catch {
            // Non-fatal: fall back to UIImpactFeedbackGenerator
        }
    }

    // MARK: - Public Events

    /// Triggered when the player taps a piece to select it.
    func pieceSelected() {
        selectionGenerator.selectionChanged()
    }

    /// Triggered on a quiet move (no capture, no check).
    func pieceMoved() {
        moveGenerator.impactOccurred()
    }

    /// Triggered when a piece is captured.
    func pieceCapture() {
        captureGenerator.impactOccurred()
        playCapturePattern()
    }

    /// Triggered when a check is delivered.
    func check() {
        checkGenerator.notificationOccurred(.warning)
        playCheckPattern()
    }

    /// Triggered on checkmate.
    func checkmate() {
        checkGenerator.notificationOccurred(.error)
        playCheckmatePattern()
    }

    /// Triggered on castling.
    func castling() {
        moveGenerator.impactOccurred(intensity: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.moveGenerator.impactOccurred(intensity: 0.4)
        }
    }

    /// Triggered on pawn promotion.
    func promotion() {
        checkGenerator.notificationOccurred(.success)
    }

    // MARK: - CoreHaptics Patterns

    private func playCapturePattern() {
        guard let engine = engine,
              CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        let events: [CHHapticEvent] = [
            CHHapticEvent(eventType: .hapticTransient,
                          parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                                       CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)],
                          relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient,
                          parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                                       CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)],
                          relativeTime: 0.08)
        ]
        try? engine.makePlayer(with: try CHHapticPattern(events: events, parameters: [])).start(atTime: 0)
    }

    private func playCheckPattern() {
        guard let engine = engine,
              CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        // Three sharp pulses — signals danger/urgency
        let times: [TimeInterval] = [0, 0.12, 0.24]
        let events: [CHHapticEvent] = times.map { t in
            CHHapticEvent(eventType: .hapticTransient,
                          parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                                       CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)],
                          relativeTime: t)
        }
        try? engine.makePlayer(with: try CHHapticPattern(events: events, parameters: [])).start(atTime: 0)
    }

    private func playCheckmatePattern() {
        guard let engine = engine,
              CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        // Long rumble that fades — signals finality
        let continuous = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                         CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)],
            relativeTime: 0,
            duration: 0.6
        )
        try? engine.makePlayer(with: try CHHapticPattern(events: [continuous], parameters: [])).start(atTime: 0)
    }
}
