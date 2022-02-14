import XCTest
import SwiftIO

@testable import VL53L0x

final class VL53L0xTests: XCTestCase {
    private var i2c: I2C!
    private var vl53l0x: VL53L0x!

    override func setUp() {
        super.setUp()
        i2c = I2C(Id.I2C0)

        i2c.expectRead = [0xEE, 0]


        vl53l0x = VL53L0x(i2c)

        XCTAssertEqual(i2c.written, [0xC0,
                                     0x88, 0, 0x80, 1, 0xFF, 1, 0, 0,
                                     0, 1, 0xFF, 0, 0x80, 0,
                                     0x60, 0x60, 0x12,
                                     0x44, 0, 32,
                                     0x01, 0xFF,
                                    ])
    }



    func testSetSignalRateLimit() {
        i2c.written = []

        vl53l0x.setSignalRateLimit(50.2555)
        XCTAssertEqual(i2c.written, [0x44, 0b00011001, 0b00100000])
    }

    func testGetSpadInfo() {
        i2c.written = []

        i2c.expectRead = [0, 0, 1, 234, 37]
        let values = vl53l0x.getSpadInfo()!
        XCTAssertEqual(values.0, 0b1101010)
        XCTAssertEqual(values.1, true)
        XCTAssertEqual(i2c.written, [0x80, 0x01, 0xFF, 0x01, 0x00, 0x00, 0xFF, 0x06,
                                    0x83, 0x83, 0x04, 0xFF, 0x07, 0x81, 0x01, 0x80, 0x01,
                                     0x94, 0x6b, 0x83, 0x00, 0x83, 0x83,
                                     0x83, 0x01, 0x92,
                                     0x81, 0x00, 0xFF, 0x06, 0x83, 0x83, 33,
                                     0xFF, 0x01, 0x00, 0x01, 0xFF, 0x00, 0x80, 0x00])

    }
    
}
