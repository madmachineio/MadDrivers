import SwiftIO
import XCTest
@testable import MS5611

final class MS5611Tests: XCTestCase {
    private var i2c: I2C!
    private var ms5611: MS5611!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)
        i2c.expectRead = [0, 0,
                          0x9C, 0xBF, 0x90, 0x3C,
                          0x5B, 0x15, 0x5A, 0xF2,
                          0x82, 0xB8, 0x6E, 0x98
        ]
        ms5611 = MS5611(i2c)
    }


    func testRead() {
        i2c.expectRead = [0x8A, 0xA2, 0x1A, 0x82, 0xC1, 0x3E]
//        ms5611.coefficient = [0, 40127, 36924, 23317, 23282, 33464, 28312]
        let values = ms5611.read()
        XCTAssertEqual(values.temperature, 20.07, accuracy: 1)
        XCTAssertEqual(values.pressure, 1000.09, accuracy: 1)
    }

}
