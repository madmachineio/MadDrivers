import SwiftIO
import XCTest
@testable import AMG88xx

final class AMG88xxTests: XCTestCase {
    private var i2c: I2C!
    private var amg88xx: AMG88xx!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)
        amg88xx = AMG88xx(i2c)

        XCTAssertEqual(i2c.written, [0x00, 0x00, 0x01, 0x3F, 0x03, 0x00, 0x02, 0x00])
        
    }

    func testReadTemperature() {
        i2c.written = []
        i2c.expectRead = [0b1111_1111, 0b0111, 0b1001_0000, 0b0001,
                          0b0000_0100, 0, 0, 0, 0b0000_0100, 0b1000,
                          0b1011_1011, 0b1011]

        XCTAssertEqual(amg88xx.readTemperature(), 127.9375)
        XCTAssertEqual(amg88xx.readTemperature(), 25)
        XCTAssertEqual(amg88xx.readTemperature(), 0.25)
        XCTAssertEqual(amg88xx.readTemperature(), 0)
        XCTAssertEqual(amg88xx.readTemperature(), -0.25)
        XCTAssertEqual(amg88xx.readTemperature(), -59.6875)
    }

    func testCalculateTemperature() {
        XCTAssertEqual(amg88xx.calculateRaw(0b1111_0100, 0b0001), 500)
        XCTAssertEqual(amg88xx.calculateRaw(0b0110_0100, 0b0), 100)
        XCTAssertEqual(amg88xx.calculateRaw(0b0000_0001, 0b0), 1)
        XCTAssertEqual(amg88xx.calculateRaw(0, 0), 0)
        XCTAssertEqual(amg88xx.calculateRaw(0b1111_1111, 0b1111), -1)
        XCTAssertEqual(amg88xx.calculateRaw(0b1001_1100, 0b1111), -100)
        XCTAssertEqual(amg88xx.calculateRaw(0b0010_0100, 0b1111), -220)

    }

}
