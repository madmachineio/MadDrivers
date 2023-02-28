import SwiftIO
import XCTest
@testable import MPR121

final class MPR121Tests: XCTestCase {
    private var i2c: I2C!
    private var mpr121: MPR121!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)
        i2c.expectRead = [0x24]
        mpr121 = MPR121(i2c)
    }

    func testReadTouchStatus() {
        i2c.expectRead = [0b0001_1010, 0b0000_1000]
        let value = mpr121.readTouchStatus()
        XCTAssertEqual(value, 0b0000_1000_0001_1010)
    }

    func testIsTouched() {
        i2c.expectRead = [0b0001_1010, 0b0000_1000]
        XCTAssertEqual(mpr121.isTouched(pin: 0), false)

        i2c.expectRead = [0b0001_1010, 0b0000_1000]
        XCTAssertEqual(mpr121.isTouched(pin: 6), false)

        i2c.expectRead = [0b0001_1010, 0b0000_1000]
        XCTAssertEqual(mpr121.isTouched(pin: 11), true)

        i2c.expectRead = [0b0001_1010, 0b0000_1000]
        XCTAssertEqual(mpr121.isTouched(pin: 12), false)

        i2c.expectRead = [0b0001_1010, 0b0000_1000]
        XCTAssertEqual(mpr121.isTouched(pin: -1), false)
    }

}

