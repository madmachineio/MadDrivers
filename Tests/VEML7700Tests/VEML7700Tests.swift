import SwiftIO
import XCTest

@testable import VEML7700

final class VEML7700Tests: XCTestCase {
    private var i2c: I2C!
    private var veml7700: VEML7700!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)
        i2c.expectRead = [0, 11, 0b1000_0000, 0b0001_0000, 0b1000_0000, 0b0001_1000]
        
        veml7700 = VEML7700(i2c)
    }

    func testPowerOn() {
        i2c.written = []
        i2c.expectRead = [11, 0]

        veml7700.powerOn()
        XCTAssertEqual(i2c.written, [0x00, 0x00, 10, 0])
    }

    func testSetIntegrationTime25() {
        i2c.written = []
        i2c.expectRead = [0b1000_0000, 0b0001_0000]

        veml7700.setIntegrationTime(.ms25)
        XCTAssertEqual(i2c.written, [0x00, 0x00, 0, 0b0001_0011])
    }

    func testSetIntegrationTime800() {
        i2c.written = []
        i2c.expectRead = [0, 0b0001_0010]

        veml7700.setIntegrationTime(.ms800)
        XCTAssertEqual(i2c.written, [0x00, 0x00, 0b1100_0000, 0b0001_0000])
    }

    func testSetGainEighth() {
        i2c.written = []
        i2c.expectRead = [0b1000_0000, 0b0001_1000]

        veml7700.setGain(.eighth)
        XCTAssertEqual(i2c.written, [0x00, 0x00, 0b1000_0000, 0b0001_0000])
    }


    func testSetGain2() {
        i2c.written = []
        i2c.expectRead = [0b1000_0000, 0b0001_1000]

        veml7700.setGain(.x2)
        XCTAssertEqual(i2c.written, [0x00, 0x00, 0b1000_0000, 0b0000_1000])
    }


    func testResolution() {
        veml7700.gain = .x2
        veml7700.integrationTime = .ms400
        XCTAssertEqual(veml7700.resolution, 0.0072)

        i2c.written = []
        veml7700.gain = .eighth
        veml7700.integrationTime = .ms25
        XCTAssertEqual(veml7700.resolution, 1.8432)
    }

    func testReadLight() {
        i2c.written = []
        i2c.expectRead = [0x02, 0x33]

        XCTAssertEqual(veml7700.readLight(), 0x3302)
        XCTAssertEqual(i2c.written, [0x04])
    }


    func testReadLux() {
        i2c.written = []
        i2c.expectRead = [0x02, 0x33, 0b1000_0000, 0b0000_1000,
                          0b1000_0000, 0b0000_1000]
        veml7700.gain = .x2
        veml7700.integrationTime = .ms400

        XCTAssertEqual(veml7700.readLux(), 94.0176)
        XCTAssertEqual(i2c.written, [0x04])
    }

    func testReadWhite() {
        i2c.written = []
        i2c.expectRead = [0x19, 0x00]

        XCTAssertEqual(veml7700.readWhite(), 0x19)
        XCTAssertEqual(i2c.written, [0x05])
    }
}

