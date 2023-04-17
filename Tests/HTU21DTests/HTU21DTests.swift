import XCTest
import SwiftIO

@testable import HTU21D

final class HTU21DTests: XCTestCase {
    private var i2c: I2C!
    private var htu21d: HTU21D!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)
        htu21d = HTU21D(i2c)
    }

    func testReset() {
        i2c.written = []
        try? htu21d.reset()
        XCTAssertEqual(i2c.written, [0xFE])
    }

    func testCalculateCRC() {
        XCTAssertEqual(htu21d.calculateCRC([0xDC]), 0x79)
        XCTAssertEqual(htu21d.calculateCRC([0x68, 0x3A]), 0x7C)
        XCTAssertEqual(htu21d.calculateCRC([0x4E, 0x85]), 0x6B)
    }

    func testReadRawValue() {
        i2c.written = []
        i2c.expectRead = [0x4E, 0x85, 0x6B]
        XCTAssertEqual(try! htu21d.readRawValue(.temperature), 0x4E84)
        XCTAssertEqual(i2c.written, [0xF3])

        i2c.written = []
        i2c.expectRead = [0x68, 0x3A, 0x7C]
        XCTAssertEqual(try! htu21d.readRawValue(.humidity), 0x6838)
        XCTAssertEqual(i2c.written, [0xF5])

        i2c.written = []
        i2c.expectRead = [0x4E, 0x85, 0]
        XCTAssertEqual(try? htu21d.readRawValue(.temperature), nil)
        XCTAssertEqual(i2c.written, [0xF3])

        i2c.written = []
        i2c.expectRead = [0x68, 0x3A, 0]
        XCTAssertEqual(try? htu21d.readRawValue(.humidity), nil)
        XCTAssertEqual(i2c.written, [0xF5])
    }

        func testReadHumidity() {
            i2c.expectRead = [0x4E, 0x85, 0x6B]
            XCTAssertEqual(try htu21d.readHumidity(), 32.3, accuracy: 0.1)

            i2c.expectRead = [0x4E, 0x85, 0]
            XCTAssertThrowsError(try htu21d.readHumidity()) { err in
                XCTAssertEqual(err as! HTU21D.HTU21DError, HTU21D.HTU21DError.crcError)
            }

            i2c.expectRead = [0x7C, 0x80, 0xF5]
            XCTAssertEqual(try htu21d.readHumidity(), 54.8, accuracy: 0.1)

            i2c.expectRead = [0, 0, 0]
            XCTAssertEqual(try htu21d.readHumidity(), -6, accuracy: 0.1)

            i2c.expectRead = [255, 255, 45]
            XCTAssertEqual(try htu21d.readHumidity(), 118.9, accuracy: 0.1)
        }

    func testReadTemperature() {
        i2c.expectRead = [0x68, 0x3A, 0x7C]
        XCTAssertEqual(try htu21d.readTemperature(), 24.7, accuracy: 0.1)

        i2c.expectRead = [0x68, 0x3A, 0]
        XCTAssertThrowsError(try htu21d.readTemperature()) { err in
            XCTAssertEqual(err as! HTU21D.HTU21DError, HTU21D.HTU21DError.crcError)
        }

        i2c.expectRead = [0x6F, 0xF5, 187]
        XCTAssertEqual(try htu21d.readTemperature(), 30, accuracy: 0.1)

        i2c.expectRead = [0xFF, 0xFC, 126]
        XCTAssertEqual(try htu21d.readTemperature(), 128.8, accuracy: 0.1)

        i2c.expectRead = [0, 0, 0]
        XCTAssertEqual(try htu21d.readTemperature(), -46.85, accuracy: 0.1)
    }

    func testSetResolution() {
        i2c.written = []
        i2c.expectRead = [0b10]
        try? htu21d.setResolution(.resolution2)
        XCTAssertEqual(i2c.written, [0xE7, 0xE6, 0b1000_0010])

        i2c.written = []
        i2c.expectRead = [0b1000_0010]
        try? htu21d.setResolution(.resolution1)
        XCTAssertEqual(i2c.written, [0xE7, 0xE6, 0b11])

        i2c.written = []
        i2c.expectRead = [0b1000_0011]
        try? htu21d.setResolution(.resolution0)
        XCTAssertEqual(i2c.written, [0xE7, 0xE6, 0b10])

        i2c.written = []
        i2c.expectRead = [0b10]
        try? htu21d.setResolution(.resolution3)
        XCTAssertEqual(i2c.written, [0xE7, 0xE6, 0b1000_0011])
    }

    func testGetResolution() {
        i2c.written = []
        i2c.expectRead = [0b1000_0010]
        XCTAssertEqual(try htu21d.getResolution(), .resolution2)
        XCTAssertEqual(i2c.written, [0xE7])

        i2c.expectRead = [0b11]
        XCTAssertEqual(try htu21d.getResolution(), .resolution1)

        i2c.expectRead = [0b10]
        XCTAssertEqual(try htu21d.getResolution(), .resolution0)

        i2c.expectRead = [0b1000_0011]
        XCTAssertEqual(try htu21d.getResolution(), .resolution3)

    }
}
