    import XCTest
    import SwiftIO

    @testable import SHT3x

    final class SHT3xTests: XCTestCase {

        private var i2c: I2C!
        private var sht: SHT3x!

        override func setUp() {
            super.setUp()

            i2c = I2C(Id.I2C0)
            sht = SHT3x(i2c)
        }

        func testInitState() {
            XCTAssertEqual(i2c.getSpeed(), .standard)
            XCTAssertEqual(i2c.written, [0x30, 0xA2])
        }

        func testFastI2C() {
            let iic = I2C(Id.I2C0, speed: .fast)
            XCTAssertEqual(iic.getSpeed(), .fast)
        }

        func testReset() {
            i2c.written = []
            sht.reset()
            XCTAssertEqual(i2c.written, [0x30, 0xA2])
        }
       
        func testZeroValue() {
            i2c.expectRead = [
                0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0,
            ]
            XCTAssertEqual(sht.readCelsius(), -45.0, "temp not equale")
            XCTAssertEqual(sht.readFahrenheit(), -49.0)
            XCTAssertEqual(sht.readHumidity(), 0.0)
        }


        func testMaxValue() {
            i2c.expectRead = [
                255, 255, 255, 255, 255, 255,
                255, 255, 255, 255, 255, 255,
                255, 255, 255, 255, 255, 255,
            ]
            XCTAssertEqual(sht.readCelsius(), 130.0)
            XCTAssertEqual(sht.readFahrenheit(), 266.0, accuracy: 0.01)
            XCTAssertEqual(sht.readHumidity(), 100.0)
        }

        func testMaxValueOneByOne() {
            i2c.expectRead = [
                255, 255, 255, 255, 255, 255
            ]
            XCTAssertEqual(sht.readCelsius(), 130.0)

            i2c.expectRead = [
                255, 255, 255, 255, 255, 255
            ]
            XCTAssertEqual(sht.readFahrenheit(), 266.0, accuracy: 0.01)

            i2c.expectRead = [
                255, 255, 255, 255, 255, 255
            ]
            XCTAssertEqual(sht.readHumidity(), 100.0)
         }


        func test25Degree() {
            let de25: UInt16 = 26214
            let tempData = de25.getBytes()

            i2c.expectRead = tempData + [0, 0, 0, 0]
            XCTAssertEqual(sht.readCelsius(), 25.0)

            i2c.expectRead = tempData + [0, 0, 0, 0]
            XCTAssertEqual(sht.readFahrenheit(), 77.0)
        }

        func test0Degree() {
            let de0: UInt16 = 16852
            let tempData = de0.getBytes()

            i2c.expectRead = tempData + [0, 0, 0, 0]
            XCTAssertEqual(sht.readCelsius(), 0, accuracy: 0.01)

            i2c.expectRead = tempData + [0, 0, 0, 0]
            XCTAssertEqual(sht.readFahrenheit(), 32.0, accuracy: 0.01)
        }


        func testHumidify() {
            let huPercent25: UInt16 = 16384
            let huPercent61: UInt16 = 40000
            
            i2c.expectRead = [0, 0, 0] + huPercent25.getBytes() + [0]
            XCTAssertEqual(sht.readHumidity(), 25, accuracy: 0.1)
            
            i2c.expectRead = [0, 0, 0] + huPercent61.getBytes() + [0]
            XCTAssertEqual(sht.readHumidity(), 61, accuracy: 0.1)
        }

    }
