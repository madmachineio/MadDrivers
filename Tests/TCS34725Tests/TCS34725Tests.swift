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
        tcs34725.setIntegrationTime(9.6)
        XCTAssertEqual(i2c.written, [129, 252])
    }

    func testReadRaw() {
        i2c.written = []
        i2c.expectRead = [0, 1, 0x33, 0x54, 0x64, 0x23, 0x56, 0xA6, 0x11, 0x5D, 3]

        let colors = tcs34725.readRaw()
        XCTAssertEqual(colors.red, 0x5433)
        XCTAssertEqual(colors.green, 0x2364)
        XCTAssertEqual(colors.blue, 0xA656)
        XCTAssertEqual(colors.clear, 0x5D11)
        XCTAssertEqual(i2c.written, [0x80, 0x80, 1, 0x80, 3,
                                     147, 150, 152, 154, 148,
                                     0x80, 0x80, 0])
    }

    func testCalculateTempLux() {
        i2c.written = []
        i2c.expectRead = [255, 0]
        let values = tcs34725.calculateTempLux(r: 200, g: 420, b: 90, c: 730)
        XCTAssertEqual(values.temp, 3105.5, accuracy: 0.1)
        XCTAssertEqual(values.lux, 52601.83, accuracy: 0.1)
        XCTAssertEqual(i2c.written, [129, 143])
    }

    func testSetGain() {
        i2c.written = []
        tcs34725.setGain(.x4)
        XCTAssertEqual(i2c.written, [143, 1])
    }

    func testGetGain() {
        i2c.written = []
        i2c.expectRead = [3]
        XCTAssertEqual(tcs34725.getGain(), .x60)
        XCTAssertEqual(i2c.written, [143])
    }


    func testCalculateRGB888() {
        i2c.written = []
        i2c.expectRead = []
        XCTAssertEqual(tcs34725.calculateRBG888(r: 632, g: 493, b: 227, c: 1418), 0x221202)
    }
}
