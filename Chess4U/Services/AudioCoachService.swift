import Foundation
import AVFoundation

// MARK: - Audio Coach Service
final class AudioCoachService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = AudioCoachService()

    @Published var isSpeaking: Bool = false
    @Published var isPaused: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var queue: [String] = []

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Speak
    func speak(_ text: String, rate: Float = 0.5, pitch: Float = 1.0) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        if synthesizer.isSpeaking {
            queue.append(text)
        } else {
            isSpeaking = true
            synthesizer.speak(utterance)
        }
    }

    func speakLesson(_ lesson: ConceptLesson) {
        let script = AICoachService.shared.generateAudioScript(for: lesson)
        speak(script, rate: 0.48)
    }

    func speakPositionComment(_ comment: String) {
        speak(comment, rate: 0.52)
    }

    func speakMoveAnalysis(quality: MoveQuality, explanation: String) {
        let intro: String
        switch quality {
        case .best:       intro = "Brilliant! "
        case .good:       intro = "Good move. "
        case .acceptable: intro = "Acceptable. "
        case .inaccuracy: intro = "An inaccuracy. "
        case .mistake:    intro = "That was a mistake. "
        case .blunder:    intro = "Oh no, that's a blunder! "
        }
        speak(intro + explanation, rate: 0.50)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        queue.removeAll()
        isSpeaking = false
        isPaused = false
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
    }

    func resume() {
        synthesizer.continueSpeaking()
        isPaused = false
    }

    func toggle() {
        if isSpeaking { isPaused ? resume() : pause() }
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if queue.isEmpty {
            isSpeaking = false
        } else {
            let next = queue.removeFirst()
            let nextUtterance = AVSpeechUtterance(string: next)
            nextUtterance.rate = 0.5
            nextUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.speak(nextUtterance)
        }
    }

    // MARK: - Lesson-based audio triggers
    func shouldTriggerAudio(event: AudioEvent, settings: AppSettings) -> Bool {
        guard settings.audioCoachEnabled else { return false }
        switch event {
        case .conceptLesson, .complexPosition, .gameAnalysis, .mistakeExplanation:
            return true
        case .puzzleSolved:
            return settings.soundEnabled
        }
    }
}

enum AudioEvent {
    case conceptLesson
    case complexPosition
    case gameAnalysis
    case mistakeExplanation
    case puzzleSolved
}
