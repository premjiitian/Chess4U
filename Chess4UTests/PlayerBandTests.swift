import XCTest
@testable import Chess4U

final class PlayerBandTests: XCTestCase {

    // MARK: - band(for:) ELO boundaries

    func testBand_under1000_isBandA()   { XCTAssertEqual(PlayerBand.band(for: 800),  .bandA) }
    func testBand_999_isBandA()         { XCTAssertEqual(PlayerBand.band(for: 999),  .bandA) }
    func testBand_1000_isBandB()        { XCTAssertEqual(PlayerBand.band(for: 1000), .bandB) }
    func testBand_1299_isBandB()        { XCTAssertEqual(PlayerBand.band(for: 1299), .bandB) }
    func testBand_1300_isBandC()        { XCTAssertEqual(PlayerBand.band(for: 1300), .bandC) }
    func testBand_1599_isBandC()        { XCTAssertEqual(PlayerBand.band(for: 1599), .bandC) }
    func testBand_1600_isBandD()        { XCTAssertEqual(PlayerBand.band(for: 1600), .bandD) }
    func testBand_1799_isBandD()        { XCTAssertEqual(PlayerBand.band(for: 1799), .bandD) }
    func testBand_1800_isBandE()        { XCTAssertEqual(PlayerBand.band(for: 1800), .bandE) }
    func testBand_2200_isBandE()        { XCTAssertEqual(PlayerBand.band(for: 2200), .bandE) }

    // MARK: - calculationDepth ranges

    func testCalculationDepth_bandA() {
        let depth = PlayerBand.bandA.calculationDepth
        XCTAssertTrue(depth.contains(2))
        XCTAssertTrue(depth.contains(3))
        XCTAssertFalse(depth.contains(1))
        XCTAssertFalse(depth.contains(4))
    }

    func testCalculationDepth_bandB() {
        let depth = PlayerBand.bandB.calculationDepth
        XCTAssertTrue(depth.contains(3))
        XCTAssertTrue(depth.contains(5))
        XCTAssertFalse(depth.contains(2))
        XCTAssertFalse(depth.contains(6))
    }

    func testCalculationDepth_bandE() {
        let depth = PlayerBand.bandE.calculationDepth
        XCTAssertTrue(depth.contains(8))
        XCTAssertTrue(depth.contains(15))
        XCTAssertFalse(depth.contains(7))
        XCTAssertFalse(depth.contains(16))
    }

    // MARK: - focusAreas

    func testFocusAreas_notEmpty() {
        for band in PlayerBand.allCases {
            XCTAssertFalse(band.focusAreas.isEmpty, "\(band.rawValue) has no focus areas")
        }
    }

    // MARK: - icon

    func testIcon_notEmpty() {
        for band in PlayerBand.allCases {
            XCTAssertFalse(band.icon.isEmpty, "\(band.rawValue) has no icon")
        }
    }
}
