import SwiftIO
import XCTest

@testable import SGP30

final class SGP30Tests: XCTestCase {
    private var i2c: I2C!
    private var sgp30: SGP30!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0, speed: .fast)

        i2c.expectRead = [23, 242, 161, 55, 65, 145, 53, 46, 221,
                          0, 0x20, 7]
        sgp30 = SGP30(i2c)

        i2c.written = [0x36, 0x82, 0x20, 0x2F, 0x20, 0x03]
    }


    func testCalculateCRC() {
        i2c.written = []

        XCTAssertEqual(sgp30.calculateCRC([0xBE, 0xEF]), 146)
    }

    func testReadRawValue() {
        i2c.written = []
        i2c.expectRead = [42, 35, 102, 183, 64, 131]

        var values = sgp30.readRawValue()
        XCTAssertEqual(values.H2, 0x2A23)
        XCTAssertEqual(values.Ethanol, 0xB740)
        XCTAssertEqual(i2c.written, [0x20, 0x50])

        i2c.expectRead = [42, 35, 100, 183, 64, 131]
        values = sgp30.readRawValue()
        XCTAssertEqual(values.H2, 0)
        XCTAssertEqual(values.Ethanol, 0)
    }

    func testReadIAQ() {
        i2c.written = []
        i2c.expectRead = [42, 35, 102, 183, 64, 131]

        var values = sgp30.readIAQ()
        XCTAssertEqual(values.eCO2, 0x2A23)
        XCTAssertEqual(values.TVOC, 0xB740)
        XCTAssertEqual(i2c.written, [0x20, 0x08])

        i2c.expectRead = [42, 35, 100, 183, 64, 131]
        values = sgp30.readIAQ()
        XCTAssertEqual(values.eCO2, 0)
        XCTAssertEqual(values.TVOC, 0)
    }

    func testGetBaseline() {
        i2c.written = []
        i2c.expectRead = [42, 35, 102, 183, 64, 131]

        var values = sgp30.getBaseline()
        XCTAssertEqual(values.eCO2, 0x2A23)
        XCTAssertEqual(values.TVOC, 0xB740)
        XCTAssertEqual(i2c.written, [0x20, 0x15])

        i2c.expectRead = [42, 35, 100, 183, 64, 131]
        values = sgp30.getBaseline()
        XCTAssertEqual(values.eCO2, 0)
        XCTAssertEqual(values.TVOC, 0)
    }

    func testSetIAQBaseline() {
        i2c.written = []
        sgp30.setBaseline(eCO2: 0x2A23, TVOC: 0xB740)
        XCTAssertEqual(i2c.written, [0x20, 0x1E, 0xB7, 0x40, 131, 0x2A, 0x23, 102])

    }

    func testSetAbsoluteHumidity() {
        i2c.written = []
        sgp30.setAbsoluteHumidity(100)
        XCTAssertEqual(i2c.written, [0x20, 0x61, 0x64, 0x00, 87])
    }

    func testSetRelativeHumidity() {
        i2c.written = []
        sgp30.setRelativeHumidity(celcius: 25, humidity: 50)
        XCTAssertEqual(i2c.written, [0x20, 0x61, 0x0B, 0x7B, 137])
    }

}
