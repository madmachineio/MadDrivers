import SwiftIO
import XCTest
@testable import BMI160

final class BMI160Tests: XCTestCase {
    private var i2c: I2C!
    private var bmi160: BMI160!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)
        i2c.written = []
        i2c.expectRead = [0xD1, 0b1001_0000, 0b1001_0100]
        bmi160 = BMI160(i2c)
    }

    func testGetChipID() {
        i2c.written = []
        i2c.expectRead = [0xD1]

        XCTAssertEqual(bmi160.getChipID(), 0xD1)
        XCTAssertEqual(i2c.written, [0x00])
    }

    func testReset() {
        i2c.written = []

        bmi160.reset()
        XCTAssertEqual(i2c.written, [0x7E, 0xB6])
    }

    func testPowerUp() {
        i2c.written = []
        i2c.expectRead = [0b1001_0000, 0b1001_0100]

        bmi160.powerUp()
        XCTAssertEqual(i2c.written, [0x7E, 0x11, 0x03, 0x7E, 0x15, 0x03])
    }

    func testSetGyroRange() {
        i2c.written = []
        bmi160.setGyroRange(.dps500)
        XCTAssertEqual(i2c.written, [0x43, 2])
    }

    func testSetAccelRange() {
        i2c.written = []
        bmi160.setAccelRange(.g4)
        XCTAssertEqual(i2c.written, [0x41, 5])
    }

    func testReadRawAcceleration() {
        i2c.written = []
        i2c.expectRead = [0x08, 0xD9, 0xF4, 0xF0, 0xFF, 0x20,
                          0xFF, 0xFF, 0x00, 0x00, 0x00, 0xFF]

        var values = bmi160.readRawAcceleration()
        XCTAssertEqual(values.x, -9976)
        XCTAssertEqual(values.y, -3852)
        XCTAssertEqual(values.z, 8447)
        XCTAssertEqual(i2c.written, [0x12])

        i2c.written = []
        values = bmi160.readRawAcceleration()
        XCTAssertEqual(values.x, -1)
        XCTAssertEqual(values.y, 0)
        XCTAssertEqual(values.z, -256)
        XCTAssertEqual(i2c.written, [0x12])
    }


    func testconvertRaw() {
        XCTAssertEqual(bmi160.convertRaw(-32768, range: 4), -4)
        XCTAssertEqual(bmi160.convertRaw(32767, range: 4), 4)
        XCTAssertEqual(bmi160.convertRaw(10000, range: 4), 1.22, accuracy: 0.01)

        XCTAssertEqual(bmi160.convertRaw(-32768, range: 16), -16)
        XCTAssertEqual(bmi160.convertRaw(32767, range: 16), 16)
        XCTAssertEqual(bmi160.convertRaw(10000, range: 16), 4.88, accuracy: 0.01)

        XCTAssertEqual(bmi160.convertRaw(-32768, range: 500), -500)
        XCTAssertEqual(bmi160.convertRaw(32767, range: 500), 500)
        XCTAssertEqual(bmi160.convertRaw(10000, range: 500), 152.60, accuracy: 0.01)
    }

    func testReadRawRotation() {
        i2c.written = []
        i2c.expectRead = [0x08, 0xD9, 0xF4, 0xF0, 0xFF, 0x20,
                          0xFF, 0xFF, 0x00, 0x00, 0x00, 0xFF]

        var values = bmi160.readRawRotation()
        XCTAssertEqual(values.x, -9976)
        XCTAssertEqual(values.y, -3852)
        XCTAssertEqual(values.z, 8447)
        XCTAssertEqual(i2c.written, [0x0C])

        i2c.written = []
        values = bmi160.readRawRotation()
        XCTAssertEqual(values.x, -1)
        XCTAssertEqual(values.y, 0)
        XCTAssertEqual(values.z, -256)
        XCTAssertEqual(i2c.written, [0x0C])
    }

    func testGetGyroRange() {
        bmi160.setGyroRange(.dps2000)
        XCTAssertEqual(bmi160.getGyroRange(), .dps2000)
    }

    func testGetAccelRange() {
        bmi160.setAccelRange(.g16)
        XCTAssertEqual(bmi160.getAccelRange(), .g16)
    }

}
