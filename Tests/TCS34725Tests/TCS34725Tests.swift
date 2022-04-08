import SwiftIO
import XCTest

@testable import TCS34725

final class TCS34725Tests: XCTestCase {
    private var i2c: I2C!
    private var tcs34725: TCS34725!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)
        i2c.expectRead = [0x44]
        tcs34725 = TCS34725(i2c)
    }

    func testGetID() {
        i2c.written = []
        i2c.expectRead = [0x44]

        XCTAssertEqual(tcs34725.getID(), 0x44)
        XCTAssertEqual(i2c.written, [146])
    }

    func testEnable() {
        i2c.written = []
        i2c.expectRead = [0]
        tcs34725.enable()
        XCTAssertEqual(i2c.written, [0x80, 0x80, 1, 0x80, 3])
    }

    func testDisable() {
        i2c.written = []
        i2c.expectRead = [0b11]
        tcs34725.disable()
        XCTAssertEqual(i2c.written, [0x80, 0x80, 0])
    }

    func testSetIntegrationTime() {
        i2c.written = []
        tcs34725.setIntegrationTime(4)
        XCTAssertEqual(i2c.written, [129, 252])
    }

    func testReadRaw() {
        i2c.written = []
        i2c.expectRead = [0, 1, 0x33, 0x54, 0x64, 0x23, 0x56, 0xA6, 0x11, 0x5D, 3]

        let colors = tcs34725.readRaw()
        XCTAssertEqual(colors.r, 0x5433)
        XCTAssertEqual(colors.g, 0x2364)
        XCTAssertEqual(colors.b, 0xA656)
        XCTAssertEqual(colors.c, 0x5D11)
        XCTAssertEqual(i2c.written, [0x80, 0x80, 1, 0x80, 3,
                                     147, 150, 152, 154, 148,
                                     0x80, 0x80, 0])
    }
}
