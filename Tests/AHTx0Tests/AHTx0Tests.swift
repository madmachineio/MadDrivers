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
        ahtx0 = AHTx0(i2c: i2c)
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
}
