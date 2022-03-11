import XCTest
import SwiftIO

@testable import VEML6070

final class VEML6070Tests: XCTestCase {
    private var i2c: I2C!
    private var veml6070: VEML6070!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)
        i2c.expectRead = [0]
        veml6070 = VEML6070(i2c)
        XCTAssertEqual(i2c.written, [0x06])
    }

    func testReadUVRaw() {
        i2c.written = []
        i2c.expectRead = [10, 20]

        XCTAssertEqual(veml6070.readUVRaw(), 0x0A14)
    }

    func testGetUVLevel() {
        i2c.written = []
        XCTAssertEqual(veml6070.getUVLevel(100), .low)
        XCTAssertEqual(veml6070.getUVLevel(560), .low)
        XCTAssertEqual(veml6070.getUVLevel(1120), .moderate)
        XCTAssertEqual(veml6070.getUVLevel(1494), .high)
        XCTAssertEqual(veml6070.getUVLevel(2054), .veryHigh)
        XCTAssertEqual(veml6070.getUVLevel(3000), .extreme)
    }

    func testSetInterrupt() {
        i2c.written = []
        veml6070.setInterrupt(enable: true, threshold: false)
        XCTAssertEqual(i2c.written, [0b100110])
    }

    func testSetIntegrationTime() {
        i2c.written = []
        veml6070.setIntegrationTime(.t2)
        XCTAssertEqual(i2c.written, [10])
    }

    func testSleep() {
        i2c.written = []
        veml6070.sleep()
        XCTAssertEqual(i2c.written, [0x03])
    }

    func testWake() {
        i2c.written = []
        veml6070.wake()
        XCTAssertEqual(i2c.written, [0x06])
    }
}

