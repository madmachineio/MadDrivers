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

    func testReadRaw() {
        i2c.written = []
        i2c.expectRead = [42, 35, 102, 183, 64, 131]

        XCTAssertEqual(sgp30.readRaw(), [0x2A23, 0xB740])
        XCTAssertEqual(i2c.written, [0x20, 0x50])
    }


}
