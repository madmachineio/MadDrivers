import SwiftIO
import XCTest
@testable import AS7341

final class AS7341Tests: XCTestCase {
    private var i2c: I2C!
    private var as7341: AS7341!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)

        i2c.expectRead = [0b00100111, 0, 0, ]
        as7341 = AS7341(i2c)

    }

    func testGetID() {
        i2c.written = []
        i2c.expectRead = [0b00100111]
        XCTAssertEqual(as7341.getID(), 0b00100100)
        XCTAssertEqual(i2c.written, [0x92])
    }

    func testPowerOn() {
        i2c.written = []
        i2c.expectRead = [0]
        as7341.powerOn()
        XCTAssertEqual(i2c.written, [0x80, 0x80, 1])
    }

    func testEnableLEDControl() {
        i2c.written = []
        i2c.expectRead = [0b0011]
        as7341.enableLEDControl()
        XCTAssertEqual(i2c.written, [0x70, 0x70, 0b1011])
    }

    func testSetAtime() {
        i2c.written = []

        as7341.setAtime(100)
        XCTAssertEqual(i2c.written, [0x81, 100])
    }

    func testSetAstep() {
        i2c.written = []

        as7341.setAstep(999)
        XCTAssertEqual(i2c.written, [0xCA, 0xE7, 0x03])
    }

    func testSetGain() {
        i2c.written = []

        as7341.setGain(.x128)
        XCTAssertEqual(i2c.written, [0xAA, 8])
    }


    func testSetSmux() {
        i2c.written = []
        as7341.setSmux(0, out1: 0, out2: 3)
        XCTAssertEqual(i2c.written, [0x00, 0x30])
    }
}
