import SwiftIO
import XCTest
@testable import MPL3115A2

final class MPL3115A2Tests: XCTestCase {
    private var i2c: I2C!
    private var mpl3115a2: MPL3115A2!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)
        i2c.expectRead = [0xC4, 0b100, 0, 0b1011_1000, 0b0001_1000]
        mpl3115a2 = MPL3115A2(i2c)
    }

    func testGetDeviceID() {
        i2c.written = []
        i2c.expectRead = [0xC4]

        XCTAssertEqual(mpl3115a2.getDeviceID(), 0xC4)
        XCTAssertEqual(i2c.written, [0x0C])
    }

    func testRest() {
        i2c.written = []
        i2c.expectRead = [0b100, 0]
        mpl3115a2.reset()
        XCTAssertEqual(i2c.written, [0x26, 0b100, 0x26, 0x26])
    }

    func testConfigure() {
        i2c.written = []
        i2c.expectRead = [0b0001_1000, 0b0011_1000]

        mpl3115a2.configure()
        XCTAssertEqual(i2c.written, [0x26, 0x26, 0b0011_1000,
                                     0x26, 0x26, 0b1011_1000,
                                     0x13, 0b111])
    }

    func testPoll() {
        i2c.written = []
        i2c.expectRead = [0b10, 0]

        mpl3115a2.poll()
        XCTAssertEqual(i2c.written, [0x26, 0x26])
    }


    func testSetMode() {
        i2c.written = []
        i2c.expectRead = [0b1011_1000, 0b0011_1000]
        mpl3115a2.setMode(.pressure)
        XCTAssertEqual(i2c.written, [0x26, 0x26, 0b0011_1000])

        i2c.written = []
        mpl3115a2.setMode(.altimeter)
        XCTAssertEqual(i2c.written, [0x26, 0x26, 0b1011_1000])
    }

    func testsetOversample() {
        i2c.written = []
        i2c.expectRead = [0b0001_1000]

        mpl3115a2.setOversample(.ratio32)
        XCTAssertEqual(i2c.written, [0x26, 0x26, 0b0010_1000])
    }

    func testReadPressure() {
        i2c.written = []
        i2c.expectRead = [0b10, 0, 0b1011_1000, 0b1011_1000, 0x04, 0x01, 0x02, 0x03]

        XCTAssertEqual(mpl3115a2.readPressure(), 1032, accuracy: 0.1)
        XCTAssertEqual(i2c.written, [0x26, 0x26,
                                     0x26, 0x26, 0b0011_1000,
                                     0x26, 0x26, 0b1011_1010,
                                     0, 0x01])
    }


    func testWaitData() {
        i2c.written = []
        i2c.expectRead = [0b1011_1000, 0, 0x04]

        mpl3115a2.waitData()
        XCTAssertEqual(i2c.written, [0x26, 0x26, 0b1011_1010, 0, 0])
    }

    func testReadAltitude() {
        i2c.written = []
        i2c.expectRead = [0b10, 0, 0b0011_1000, 0b1011_1000, 0x04, 0x10, 0x02, 0x03]

        XCTAssertEqual(mpl3115a2.readAltitude(), 4098.074, accuracy: 0.1)
        XCTAssertEqual(i2c.written, [0x26, 0x26,
                                     0x26, 0x26, 0b1011_1000,
                                     0x26, 0x26, 0b1011_1010,
                                     0, 0x01])
    }

    func testReadTemperature() {
        i2c.written = []
        i2c.expectRead = [0, 0x02, 0x10, 0x01]
        XCTAssertEqual(mpl3115a2.readTemperature(), 16, accuracy: 0.1)
        XCTAssertEqual(i2c.written, [0, 0, 0x04])


        i2c.written = []
        i2c.expectRead = [0, 0x02, 0xF0, 0x01]
        XCTAssertEqual(mpl3115a2.readTemperature(), -15.99, accuracy: 0.1)
        XCTAssertEqual(i2c.written, [0, 0, 0x04])
    }

    func testGetSeaLevelPressure() {
        i2c.written = []
        i2c.expectRead = [0x01, 0x02]
        XCTAssertEqual(mpl3115a2.getSeaLevelPressure(), 516)
        XCTAssertEqual(i2c.written, [0x14])
    }

    func testSetSeaLevelPressure() {
        i2c.written = []
        mpl3115a2.setSeaLevelPressure(100000)
        XCTAssertEqual(i2c.written, [0x14, 0xC3, 0x50])
    }
}
