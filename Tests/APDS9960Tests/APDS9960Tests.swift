    import XCTest
    import SwiftIO
    @testable import APDS9960

    final class APDS9960Tests: XCTestCase {

        private var i2c: I2C!
        private var apds: APDS9960!

        override func setUp() {
            super.setUp()
            i2c = I2C(Id.I2C0)

            i2c.written = []
            i2c.expectRead = [0xAB, 1, 0, 0b10, 0b100, 0b1_0000, 0b10_0000, 0b01, 0, 0, 0, 0, ]

            apds = APDS9960(i2c)

        }

        func testInit() {
            XCTAssert(i2c.getSpeed() == .standard || i2c.getSpeed() == .fast)
        }

        func testRotatedGesture() {
            let i2cLocal = I2C(Id.I2C0)
            i2cLocal.written = []
            i2cLocal.expectRead = [0xAB, 1, 0, 0b10, 0b100, 0b1_0000, 0b10_0000, 0b01, 0, 0, 0, 0, ]

            let apdsLocal = APDS9960(i2cLocal, rotation: .degree90)
            XCTAssertEqual(apdsLocal.rotatedGesture(.up), .right)
        }

        func testSetGPulse() {
            i2c.written = []
            apds.setGPulse(length: .us16, count: 3)
            XCTAssertEqual(i2c.written, [0xA6, 0b1000_0011])
        }


        func testEnableGesture() {
            i2c.written = []
            i2c.expectRead = [0]
            apds.enableGesture()
            XCTAssertEqual(i2c.written, [0x80, 0x80, 0b0100_0000])
        }

        func testDisableGesture() {
            i2c.written = []
            i2c.expectRead = [1, 0]
            apds.disableGesture()
            XCTAssertEqual(i2c.written, [0xAB, 0xAB, 0, 0x80, 0x80, 0])
        }

        func testClearInterrupt() {
            i2c.written = []
            apds.clearInterrupt()
            XCTAssertEqual(i2c.written, [0xE7])
        }


        func testSetGPThreshold() {
            i2c.written = []
            apds.setGPThreshold(50)
            XCTAssertEqual(i2c.written, [0xA0, 50])
        }

        func testGetID() {
            i2c.expectRead = [0xAB]
            i2c.written = []
            XCTAssertEqual(apds.getDeviceID(), 0xAB)
            XCTAssertEqual(i2c.written, [0x92])
        }

        func testSetColorIntergrationTime() {
            i2c.written = []
            apds.setColorIntegrationTime(2.78)
            XCTAssertEqual(i2c.written, [0x81, 0xFF])

            i2c.written = []
            apds.setColorIntegrationTime(712)
            XCTAssertEqual(i2c.written, [0x81, 0])

            i2c.written = []
            apds.setColorIntegrationTime(27.8)
            XCTAssertEqual(i2c.written, [0x81, 0xF6])
        }


        func testGetAvailable() {
            i2c.written = []
            i2c.expectRead = [20]
            XCTAssertEqual(apds.getGAvailable(), 80)
            XCTAssertEqual(i2c.written, [0xAE])

            i2c.written = []
            i2c.expectRead = [40]
            XCTAssertEqual(apds.getGAvailable(), 128)
            XCTAssertEqual(i2c.written, [0xAE])

        }

        func testReadColor() {
            i2c.written = []
            i2c.expectRead = [1] + [255, 255, 255, 255, 255, 255, 255, 255]
            var color = apds.readColor()
            XCTAssert(color.red == 65535 && color.green == 65535 &&
                      color.blue == 65535 && color.clear == 65535)
            XCTAssertEqual(i2c.written, [0x93, 0x94])

            i2c.written = []
            i2c.expectRead = [1] + [255, 255, 255, 255, 255, 255, 255, 255]
            color = apds.readColor()
            XCTAssert(color.red == 65535 && color.green == 65535 &&
                      color.blue == 65535 && color.clear == 65535)
            XCTAssertEqual(i2c.written, [0x93, 0x94])


            i2c.written = []
            i2c.expectRead = [1] + [0, 0, 0, 0, 0, 0, 0, 0]
            color = apds.readColor()
            XCTAssert(color.red == 0 && color.green == 0 &&
                      color.blue == 0 && color.clear == 0)
            XCTAssertEqual(i2c.written, [0x93, 0x94])

            i2c.written = []
            i2c.expectRead = [1] + [112, 34, 200, 160, 120, 10, 45, 250]
            let clear = i2c.expectRead.getUInt16(from: 1, endian: .little)
            let red = i2c.expectRead.getUInt16(from: 3, endian: .little)
            let green = i2c.expectRead.getUInt16(from: 5, endian: .little)
            let blue = i2c.expectRead.getUInt16(from: 7, endian: .little)
            color = apds.readColor()
            XCTAssert(color.red == red && color.green == green &&
                      color.blue == blue && color.clear == clear)
            XCTAssertEqual(i2c.written, [0x93, 0x94])
        }

        func testReadProximity() {
            i2c.written = []
            i2c.expectRead = [0]
            XCTAssertEqual(apds.readProximity(), 0)
            XCTAssertEqual(i2c.written, [0x9C])

            i2c.written = []
            i2c.expectRead = [255]
            XCTAssertEqual(apds.readProximity(), 255)
            XCTAssertEqual(i2c.written, [0x9C])
        }

        func testReadGestureRaw() {
            i2c.written = []
            i2c.expectRead = [0x01, 0x0F, 0x0F, 0x0F, 0x0F]
            XCTAssertEqual(apds.readRawGesture(), [0x0F, 0x0F, 0x0F, 0x0F])
            XCTAssertEqual(i2c.written, [0xAE, 0xFC])


            i2c.written = []
            i2c.expectRead = [0x02,
                              0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6, 0xFF, 0xFF]
            XCTAssertEqual(apds.readRawGesture(), [0xA1, 0xB2, 0xC3, 0xD4])
            XCTAssertEqual(i2c.written, [0xAE, 0xFC])
        }


        func testCalculateGesture() {
            i2c.written = []
            i2c.expectRead = [0x01, 0x01,
                              100, 150, 200, 210,
                              0x01,
                              200, 150, 200, 210]
            XCTAssertEqual(apds.calculateGesture(), .down)
            XCTAssertEqual(i2c.written, [0xAF, 0xAE, 0xFC, 0xAE, 0xFC])

            i2c.written = []
            i2c.expectRead = [0x01, 0x01,
                              200, 150, 200, 210,
                              0x01,
                              120, 150, 200, 210,]
            XCTAssertEqual(apds.calculateGesture(), .up)
            XCTAssertEqual(i2c.written, [0xAF, 0xAE, 0xFC, 0xAE, 0xFC])

            i2c.written = []
            i2c.expectRead = [0x01, 0x01,
                              160, 150, 160, 210,
                              0x01,
                              160, 150, 240, 210,]
            XCTAssertEqual(apds.calculateGesture(), .right)
            XCTAssertEqual(i2c.written, [0xAF, 0xAE, 0xFC, 0xAE, 0xFC])


            i2c.written = []
            i2c.expectRead = [0x01, 0x01,
                              160, 150, 250, 210,
                              0x01,
                              160, 150, 160, 210,]
            XCTAssertEqual(apds.calculateGesture(), .left)
            XCTAssertEqual(i2c.written, [0xAF, 0xAE, 0xFC, 0xAE, 0xFC])

        }

        func testEnable() {
            i2c.written = []
            i2c.expectRead = [0]
            apds.enable()
            XCTAssertEqual(i2c.written, [0x80, 0x80, 0x01])
        }

        func testDisable() {
            i2c.written = []
            i2c.expectRead = [0b01]
            apds.disable()
            XCTAssertEqual(i2c.written, [0x80, 0x80, 0])
        }

        func testEnableColor() {
            i2c.written = []
            i2c.expectRead = [0]
            apds.enableColor()
            XCTAssertEqual(i2c.written, [0x80, 0x80, 0x02])
        }

        func testDisableColor() {
            i2c.written = []
            i2c.expectRead = [0b10]
            apds.disableColor()
            XCTAssertEqual(i2c.written, [0x80, 0x80, 0])
        }

        func testEnableProximity() {
            i2c.written = []
            i2c.expectRead = [0]
            apds.enableProximity()
            XCTAssertEqual(i2c.written, [0x80, 0x80, 0x04])
        }

        func testDisableProximity() {
            i2c.written = []
            i2c.expectRead = [0b100]
            apds.disableProximity()
            XCTAssertEqual(i2c.written, [0x80, 0x80, 0])
        }


        func testEnableProximityInterrupt() {
            i2c.written = []
            i2c.expectRead = [0]
            apds.enableProximityInterrupt()
            XCTAssertEqual(i2c.written, [0x80, 0x80, 0b0010_0000])
        }

        func testDisableProximityInterrupt() {
            i2c.written = []
            i2c.expectRead = [0b10_0000]
            apds.disableProximityInterrupt()
            XCTAssertEqual(i2c.written, [0x80, 0x80, 0])
        }

        func testEnableColorInterrupt() {
            i2c.written = []
            i2c.expectRead = [0]
            apds.enableColorInterrupt()
            XCTAssertEqual(i2c.written, [0x80, 0x80, 0b0001_0000])
        }

        func testDisableColorInterrupt() {
            i2c.written = []
            i2c.expectRead = [0b1_0000]
            apds.disableColorInterrupt()
            XCTAssertEqual(i2c.written, [0x80, 0x80, 0])
        }

        func testSetColorGain() {
            i2c.written = []
            i2c.expectRead = [0]
            apds.setColorGain(.x4)
            XCTAssertEqual(i2c.written, [0x8F, 0x8F, 0b01])
        }

        func testSetGestureGain() {
            i2c.written = []
            i2c.expectRead = [0]
            apds.setGestureGain(.x4)
            XCTAssertEqual(i2c.written, [0xA3, 0xA3, 0b0100_0000])
        }

        func testSetGestureFIFOThreshold() {
            i2c.written = []
            i2c.expectRead = [0]
            apds.setGestureFIFOThreshold(.threshold4)
            XCTAssertEqual(i2c.written, [0xA2, 0xA2, 0b0100_0000])
        }

        func testSetGestureDimensions() {
            i2c.written = []
            apds.setGestureDimensions(.all)
            XCTAssertEqual(i2c.written, [0xAA, 0])
        }


        
    }
