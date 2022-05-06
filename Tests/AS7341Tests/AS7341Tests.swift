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
        as7341.setSmux(.NC_F3L, .disable, .adc2)
        XCTAssertEqual(i2c.written, [0x00, 0x30])
    }


    func testSetSmuxF1F4() {
        i2c.written = []
        as7341.setSmuxF1F4()
        XCTAssertEqual(i2c.written, [0x00, 0x30, 0x01, 0x01,
                                     0x02, 0x00, 0x03, 0x00,
                                     0x04, 0x00, 0x05, 0x42,
                                     0x06, 0x00, 0x07, 0x00,
                                     0x08, 0x50, 0x09, 0x00,
                                     0x0A, 0x00, 0x0B, 0x00,
                                     0x0C, 0x20, 0x0D, 0x04,
                                     0x0E, 0x00, 0x0F, 0x30,
                                     0x10, 0x01, 0x11, 0x50,
                                     0x12, 0x00, 0x13, 0x06])
    }

    func testSetSmuxF5F8() {
        i2c.written = []
        as7341.setSmuxF5F8()
        XCTAssertEqual(i2c.written, [0x00, 0x00, 0x01, 0x00,
                                     0x02, 0x00, 0x03, 0x40,
                                     0x04, 0x02, 0x05, 0x00,
                                     0x06, 0x10, 0x07, 0x03,
                                     0x08, 0x50, 0x09, 0x10,
                                     0x0A, 0x03, 0x0B, 0x00,
                                     0x0C, 0x00, 0x0D, 0x00,
                                     0x0E, 0x24, 0x0F, 0x00,
                                     0x10, 0x00, 0x11, 0x50,
                                     0x12, 0x00, 0x13, 0x06])
    }

    func testWaitData() {
        i2c.written = []
        i2c.expectRead = [64]

        as7341.waitData()
        XCTAssertEqual(i2c.written, [0xA3])
    }

    func testEnableColorMeasure() {
        i2c.written = []
        i2c.expectRead = [65]

        as7341.enableColorMeasure()
        XCTAssertEqual(i2c.written, [0x80, 0x80, 67])
    }


    func testDisableColorMeasure() {
        i2c.written = []
        i2c.expectRead = [67]

        as7341.disableColorMeasure()
        XCTAssertEqual(i2c.written, [0x80, 0x80, 65])
    }

    func testEnableSmux() {
        i2c.written = []
        i2c.expectRead = [16, 3, 0]

        as7341.enableSmux()
        XCTAssertEqual(i2c.written, [0xA9, 0xA9, 0, 0x80, 0x80, 19, 0x80])
    }

    func testsetSmuxCommand() {
        i2c.written = []
        as7341.setSmuxCommand(2)
        XCTAssertEqual(i2c.written, [0xAF, 16])
    }

    func testSetF1F4() {
        i2c.written = []
        i2c.expectRead = [67, 16, 3, 0, 65, 64]

        as7341.setF1F4()
        XCTAssertEqual(i2c.written, [0x80, 0x80, 65,
                                     0xAF, 16,
                                     0x00, 0x30, 0x01, 0x01,
                                     0x02, 0x00, 0x03, 0x00,
                                     0x04, 0x00, 0x05, 0x42,
                                     0x06, 0x00, 0x07, 0x00,
                                     0x08, 0x50, 0x09, 0x00,
                                     0x0A, 0x00, 0x0B, 0x00,
                                     0x0C, 0x20, 0x0D, 0x04,
                                     0x0E, 0x00, 0x0F, 0x30,
                                     0x10, 0x01, 0x11, 0x50,
                                     0x12, 0x00, 0x13, 0x06,
                                     0xA9, 0xA9, 0, 0x80, 0x80, 19, 0x80,
                                     0x80, 0x80, 67,
                                     0xA3])
    }

    func testSetF5F8() {
        i2c.written = []
        i2c.expectRead = [67, 16, 3, 0, 65, 64]
        as7341.lowChannels = true

        as7341.setF5F8()
        XCTAssertEqual(i2c.written, [0x80, 0x80, 65,
                                     0xAF, 16,
                                     0x00, 0x00, 0x01, 0x00,
                                     0x02, 0x00, 0x03, 0x40,
                                     0x04, 0x02, 0x05, 0x00,
                                     0x06, 0x10, 0x07, 0x03,
                                     0x08, 0x50, 0x09, 0x10,
                                     0x0A, 0x03, 0x0B, 0x00,
                                     0x0C, 0x00, 0x0D, 0x00,
                                     0x0E, 0x24, 0x0F, 0x00,
                                     0x10, 0x00, 0x11, 0x50,
                                     0x12, 0x00, 0x13, 0x06,
                                     0xA9, 0xA9, 0, 0x80, 0x80, 19, 0x80,
                                     0x80, 0x80, 67,
                                     0xA3])
    }

    func testReadChannels() {
        i2c.written = []
        i2c.expectRead = [67, 16, 3, 0, 65, 64,
                          0x10, 0x20, 0x23, 0x35, 0x64, 0x13, 0x36,
                          0x64, 0xAB, 0x35, 0xC3, 0xF2, 0x43,
                          67, 16, 3, 0, 65, 64,
                          0x33, 0x44, 0x45, 0x35, 0x46, 0xB0, 0xC3,
                          0x38, 0x87, 0xEF, 0x19, 0x82, 0x40]
        let readings = as7341.readChannels()

        XCTAssertEqual(readings.f1, 0x2320)
        XCTAssertEqual(readings.f2, 0x6435)
        XCTAssertEqual(readings.f3, 0x3613)
        XCTAssertEqual(readings.f4, 0xAB64)
        XCTAssertEqual(readings.f5, 0x4544)
        XCTAssertEqual(readings.f6, 0x4635)
        XCTAssertEqual(readings.f7, 0xC3B0)
        XCTAssertEqual(readings.f8, 0x8738)
        XCTAssertEqual(readings.clear, 0x19EF)
        XCTAssertEqual(readings.nir, 0x4082)
        XCTAssertEqual(i2c.written, [0x80, 0x80, 65,
                                     0xAF, 16,
                                     0x00, 0x30, 0x01, 0x01,
                                     0x02, 0x00, 0x03, 0x00,
                                     0x04, 0x00, 0x05, 0x42,
                                     0x06, 0x00, 0x07, 0x00,
                                     0x08, 0x50, 0x09, 0x00,
                                     0x0A, 0x00, 0x0B, 0x00,
                                     0x0C, 0x20, 0x0D, 0x04,
                                     0x0E, 0x00, 0x0F, 0x30,
                                     0x10, 0x01, 0x11, 0x50,
                                     0x12, 0x00, 0x13, 0x06,
                                     0xA9, 0xA9, 0, 0x80, 0x80, 19, 0x80,
                                     0x80, 0x80, 67,
                                     0xA3,
                                     0x94,
                                     0x80, 0x80, 65,
                                     0xAF, 16,
                                     0x00, 0x00, 0x01, 0x00,
                                     0x02, 0x00, 0x03, 0x40,
                                     0x04, 0x02, 0x05, 0x00,
                                     0x06, 0x10, 0x07, 0x03,
                                     0x08, 0x50, 0x09, 0x10,
                                     0x0A, 0x03, 0x0B, 0x00,
                                     0x0C, 0x00, 0x0D, 0x00,
                                     0x0E, 0x24, 0x0F, 0x00,
                                     0x10, 0x00, 0x11, 0x50,
                                     0x12, 0x00, 0x13, 0x06,
                                     0xA9, 0xA9, 0, 0x80, 0x80, 19, 0x80,
                                     0x80, 0x80, 67,
                                     0xA3,
                                     0x94])
    }

}








