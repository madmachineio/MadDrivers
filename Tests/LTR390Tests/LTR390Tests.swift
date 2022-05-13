import SwiftIO
import XCTest
@testable import LTR390

final class LTR390Tests: XCTestCase {
    private var i2c: I2C!
    private var ltr390: LTR390!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)
        i2c.expectRead = [0xB2, 0, 2, 2, 19]
        ltr390 = LTR390(i2c)
        
    }

    func testGetID() {
        i2c.written = []
        i2c.expectRead = [0xB2]

        XCTAssertEqual(ltr390.getID(), 0xB2)
        XCTAssertEqual(i2c.written, [0x06])
    }

    func testReset() {
        i2c.written = []
        ltr390.reset()

        XCTAssertEqual(i2c.written, [0, 0, 0x04, 0x22, 0x05, 0x01,
                                     0x19, 0x10, 0x1A, 0,
                                     0x21, 0xFF, 0xFF, 0x0F,
                                     0x24, 0, 0, 0])
    }

    func testEnable() {
        i2c.written = []
        i2c.expectRead = [0]

        ltr390.enable()
        XCTAssertEqual(i2c.written, [0, 0, 2])
    }

    func testEnabled() {
        i2c.written = []
        i2c.expectRead = [0b11010]

        XCTAssertEqual(ltr390.enabled(), true)
        XCTAssertEqual(i2c.written, [0])

        i2c.written = []
        i2c.expectRead = [0b1000]

        XCTAssertEqual(ltr390.enabled(), false)
        XCTAssertEqual(i2c.written, [0])
    }

    func testSetModeUVS() {
        i2c.written = []
        i2c.expectRead = [2]
        ltr390.setMode(.als)
        XCTAssertEqual(i2c.written, [0, 0, 2])

        i2c.written = []
        i2c.expectRead = [2]
        ltr390.setMode(.uvs)
        XCTAssertEqual(i2c.written, [0, 0, 10])

    }

    func testGetMode() {
        i2c.written = []
        i2c.expectRead = [10, 2]
        XCTAssertEqual(ltr390.getMode(), .uvs)
        XCTAssertEqual(i2c.written, [0])

        i2c.written = []
        i2c.expectRead = [2]
        XCTAssertEqual(ltr390.getMode(), .als)
        XCTAssertEqual(i2c.written, [0])
    }

    func testSetGain() {
        i2c.written = []
        ltr390.setGain(.x3)
        XCTAssertEqual(i2c.written, [0x05, 1])

        i2c.written = []
        ltr390.setGain(.x18)
        XCTAssertEqual(i2c.written, [0x05, 4])
    }

    func testGetGain() {
        i2c.written = []
        i2c.expectRead = [3]
        XCTAssertEqual(ltr390.getGain(), .x9)
        XCTAssertEqual(i2c.written, [0x05])

        i2c.written = []
        i2c.expectRead = [2]
        XCTAssertEqual(ltr390.getGain(), .x6)
        XCTAssertEqual(i2c.written, [0x05])
    }

    func testSetResolution() {
        i2c.written = []
        i2c.expectRead = [3]
        ltr390.setResolution(.bit13)
        XCTAssertEqual(i2c.written, [0x04, 0x04, 83])

        i2c.written = []
        i2c.expectRead = [3]
        ltr390.setResolution(.bit19)
        XCTAssertEqual(i2c.written, [0x04, 0x04, 19])
    }

    func testGetResolution() {
        i2c.written = []
        i2c.expectRead = [83]
        XCTAssertEqual(ltr390.getResolution(), .bit13)
        XCTAssertEqual(i2c.written, [0x04])

        i2c.written = []
        i2c.expectRead = [19]
        XCTAssertEqual(ltr390.getResolution(), .bit19)
        XCTAssertEqual(i2c.written, [0x04])

    }

    func testIsDtatReady() {
        i2c.written = []
        i2c.expectRead = [8]
        XCTAssertEqual(ltr390.isDtatReady(), true)
        XCTAssertEqual(i2c.written, [0x07])

        i2c.written = []
        i2c.expectRead = [32]
        XCTAssertEqual(ltr390.isDtatReady(), false)
        XCTAssertEqual(i2c.written, [0x07])
    }

    func testReadUV() {
        i2c.written = []
        i2c.expectRead = [0, 8, 0x10, 0x20, 0x06]
        XCTAssertEqual(ltr390.readUV(), 0x062010)
        XCTAssertEqual(i2c.written, [0x07, 0x07, 0x10])
    }

    func testReadLight() {
        i2c.written = []
        i2c.expectRead = [2, 8, 0x44, 0x66, 0x05]
        XCTAssertEqual(ltr390.readLight(), 0x056644)
        XCTAssertEqual(i2c.written, [0, 0, 2, 0x07, 0x0D])
    }

    func testReadLux() {
        i2c.expectRead = [2, 8, 0xFF, 0, 0]
        XCTAssertEqual(ltr390.readLux(), 204, accuracy: 0.1)

        i2c.expectRead = [2, 8, 0x61, 0x80, 0]
        XCTAssertEqual(ltr390.readLux(), 26292, accuracy: 0.1)
    }

    func testReadUVI() {
        i2c.expectRead = [0, 8, 0xF5, 0, 0]
        XCTAssertEqual(ltr390.readUVI(), 10.2, accuracy: 0.1)

        i2c.expectRead = [3, 0, 8, 0xA6, 0x34, 0]
        ltr390.setGain(.x18)
        ltr390.setResolution(.bit20)
        XCTAssertEqual(ltr390.readUVI(), 5.86, accuracy: 0.1)

    }

}



            

