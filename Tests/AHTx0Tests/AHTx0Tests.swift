import XCTest
import SwiftIO

@testable import AHTx0

final class AHTx0Tests: XCTestCase {
    private var i2c: I2C!
    private var ahtx0: AHTx0!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)

        i2c.expectRead = [0x08]
        ahtx0 = AHTx0(i2c)
    }

    func testReset() {
        i2c.written = []
        ahtx0.reset()
        XCTAssertEqual(i2c.written, [0xBA])
    }

    func testCalibrate() {
        i2c.written = []
        i2c.expectRead = [0x08]
        ahtx0.calibrate()
        XCTAssertEqual(i2c.written, [0xE1, 0x08, 0x00])

    }

    func testReadStatus() {
        i2c.written = []
        i2c.expectRead = [0x80]
        XCTAssertEqual(ahtx0.readStatus(), 0x80)
    }

    func testReadHumidity() {
        i2c.written = []
        i2c.expectRead = [0, 0x00, 0x97, 0x5E, 0x05, 0x99, 0x98]

        XCTAssertEqual(ahtx0.readHumidity(), 59.13, accuracy: 0.1)
        XCTAssertEqual(i2c.written, [0xAC, 0x33, 0x00])
    }

    func testReadCelcius() {
        i2c.written = []
        i2c.expectRead = [0, 0x00, 0x97, 0x5E, 0x05, 0x99, 0x98]

        XCTAssertEqual(ahtx0.readCelsius(), 19.99, accuracy: 0.1)
        XCTAssertEqual(i2c.written, [0xAC, 0x33, 0x00])
    }


}

