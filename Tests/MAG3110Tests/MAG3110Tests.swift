import XCTest
import SwiftIO
@testable import MAG3110

final class MAG3110Tests: XCTestCase {
    private var i2c: I2C!
    private var mag3110: MAG3110!

    override func setUp() {
        super.setUp()
        i2c = I2C(Id.I2C0)
        i2c.expectRead = [0xC4, 0xFF, 0xFF]
        mag3110 = MAG3110(i2c)
        
    }

    func testGetDeviceID() {
        i2c.written = []
        i2c.expectRead = [0xC4]
        XCTAssertEqual(mag3110.getDeviceID(), 0xC4)
        XCTAssertEqual(i2c.written, [0x07])
    }

    func testSetMode() {
        i2c.written = []
        i2c.expectRead = [0xFF]
        mag3110.setMode(.standby)
        XCTAssertEqual(i2c.written, [0x10, 0x10, 0xFC])

    }

    func testSetOffset() {
        i2c.written = []
        mag3110.setOffset(x: 20, y: 30, z: 40)
        XCTAssertEqual(i2c.written, [0x09, 0, 0x28, 0, 0x3C, 0, 0x50])
    }

    func testReset() {
        i2c.written = []
        i2c.expectRead = [0xFF, 0xFF]
        mag3110.reset()
        XCTAssertEqual(i2c.written, [0x10, 0x10, 0xFC,
                                     0x10, 0, 0x11, 0x80,
                                     0x09, 0, 0, 0, 0, 0, 0,
                                     0x10, 0x10, 0xFD])
    }

    func testIsDataAvailable() {
        i2c.written = []
        i2c.expectRead = [0]
        XCTAssertEqual(mag3110.isDataAvailable(), false)
    }

    func testReadRawValues() {
        i2c.written = []
        i2c.expectRead = [0x80, 100, 20, 35, 60, 45, 180]
        let x = i2c.expectRead.getInt16(from: 1)
        let y = i2c.expectRead.getInt16(from: 3)
        let z = i2c.expectRead.getInt16(from: 5)
        let values = mag3110.readRawValues()
        XCTAssert(values.x == x && values.y == y && values.z == z)
    }

    func testReadMicroTeslas() {
        i2c.written = []
        i2c.expectRead = [0x80, 100, 20, 35, 60, 45, 180]
        let x = Float(i2c.expectRead.getInt16(from: 1)) * 0.1
        let y = Float(i2c.expectRead.getInt16(from: 3)) * 0.1
        let z = Float(i2c.expectRead.getInt16(from: 5)) * 0.1
        let values = mag3110.readMicroTeslas()
        XCTAssert(values.x == x && values.y == y && values.z == z)
    }

    func testSetMeasurement() {
        i2c.written = []
        i2c.expectRead = [0, 0]
        mag3110.setMeasurement(datarate: 3, sampling: .x16)
        XCTAssertEqual(i2c.written, [0x08, 0x10, 0x10, 0x60])
    }

    func testGetMode() {
        i2c.written = []
        i2c.expectRead = [0]
        XCTAssertEqual(mag3110.getMode(), .standby)
        XCTAssertEqual(i2c.written, [0x08])
    }

}
