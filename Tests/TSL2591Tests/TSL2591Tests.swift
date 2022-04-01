import XCTest
import SwiftIO

@testable import TSL2591

final class TSL2591Tests: XCTestCase {
    private var i2c: I2C!
    private var tsl2591: TSL2591!

    override func setUp() {
        super.setUp()
        i2c = I2C(Id.I2C0)
        i2c.expectRead = [0x50, 10]
        tsl2591 = TSL2591(i2c)
    }

    func testGetDeviceID() {
        i2c.written = []
        i2c.expectRead = [0x50]

        XCTAssertEqual(tsl2591.getDeviceID(), 0x50)
        XCTAssertEqual(i2c.written, [0b10110010])
    }

    func testEnable() {
        i2c.written = []
        tsl2591.enable()
        XCTAssertEqual(i2c.written, [0xA0, 0b10010011])
    }

    func testReadRaw() {
        i2c.written = []
        i2c.expectRead = [1, 2, 3, 4]
        let values = tsl2591.readRaw()
        XCTAssertEqual(values.0, 513)
        XCTAssertEqual(values.1, 1027)
        XCTAssertEqual(i2c.written, [0xB4, 0xB6])
    }

    func testSetGain() {
        i2c.written = []
        i2c.expectRead = [10]
        tsl2591.setGain(.medium)
        XCTAssertEqual(i2c.written, [161, 161, 26])
    }

    func testGetGain() {
        i2c.written = []
        i2c.expectRead = [32]
        XCTAssertEqual(tsl2591.getGain(), .high)
        XCTAssertEqual(i2c.written, [161])
    }
}

