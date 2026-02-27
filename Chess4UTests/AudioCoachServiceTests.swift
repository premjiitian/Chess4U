import XCTest
@testable import Chess4U

final class AudioCoachServiceTests: XCTestCase {

    private let coach = AudioCoachService.shared

    private func settings(audioCoach: Bool = true, sound: Bool = true) -> AppSettings {
        var s = AppSettings()
        s.audioCoachEnabled = audioCoach
        s.soundEnabled      = sound
        return s
    }

    // MARK: - shouldTriggerAudio: audioCoachEnabled = false

    func testShouldTrigger_audioDisabled_alwaysFalse() {
        let off = settings(audioCoach: false)
        for event in [AudioEvent.conceptLesson, .complexPosition, .gameAnalysis,
                      .mistakeExplanation, .puzzleSolved] {
            XCTAssertFalse(coach.shouldTriggerAudio(event: event, settings: off),
                "\(event) should not trigger when audioCoach is disabled")
        }
    }

    // MARK: - shouldTriggerAudio: audioCoachEnabled = true

    func testShouldTrigger_conceptLesson_trueWhenEnabled() {
        XCTAssertTrue(coach.shouldTriggerAudio(event: .conceptLesson, settings: settings()))
    }

    func testShouldTrigger_complexPosition_trueWhenEnabled() {
        XCTAssertTrue(coach.shouldTriggerAudio(event: .complexPosition, settings: settings()))
    }

    func testShouldTrigger_gameAnalysis_trueWhenEnabled() {
        XCTAssertTrue(coach.shouldTriggerAudio(event: .gameAnalysis, settings: settings()))
    }

    func testShouldTrigger_mistakeExplanation_trueWhenEnabled() {
        XCTAssertTrue(coach.shouldTriggerAudio(event: .mistakeExplanation, settings: settings()))
    }

    // MARK: - shouldTriggerAudio: puzzleSolved follows soundEnabled

    func testShouldTrigger_puzzleSolved_trueWhenSoundEnabled() {
        XCTAssertTrue(coach.shouldTriggerAudio(event: .puzzleSolved,
                                               settings: settings(audioCoach: true, sound: true)))
    }

    func testShouldTrigger_puzzleSolved_falseWhenSoundDisabled() {
        XCTAssertFalse(coach.shouldTriggerAudio(event: .puzzleSolved,
                                                settings: settings(audioCoach: true, sound: false)))
    }

    // MARK: - Other events unaffected by soundEnabled

    func testShouldTrigger_conceptLesson_trueEvenWhenSoundDisabled() {
        // Non-puzzle events always return true when audioCoach is enabled,
        // regardless of soundEnabled
        XCTAssertTrue(coach.shouldTriggerAudio(event: .conceptLesson,
                                               settings: settings(audioCoach: true, sound: false)))
    }
}
