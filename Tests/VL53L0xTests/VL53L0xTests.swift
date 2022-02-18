import XCTest
import SwiftIO

@testable import VL53L0x

final class VL53L0xTests: XCTestCase {
    private var i2c: I2C!
    private var vl53l0x: VL53L0x!

    override func setUp() {
        super.setUp()
        i2c = I2C(Id.I2C0)

        i2c.expectRead = [0xEE, 2, 0,
                          0, 0, 1, 138, 37, 10, 20, 30, 40, 50, 60, 20,
                          187, 3, 15, 5, 28, 4, 5, 7,
                          187, 3, 15, 5, 28, 4, 5, 7,
                          1, 1]

        vl53l0x = VL53L0x(i2c)
    }

    func testDataInit() {
        i2c.written = []
        i2c.expectRead = [2, 0]

        vl53l0x.dataInit()
        XCTAssertEqual(i2c.written, [0x88, 0, 0x80, 1, 0xFF, 1, 0, 0, 0x91,
                                     0, 1, 0xFF, 0, 0x80, 0,
                                     0x60, 0x60, 0x12,
                                     0x44, 0, 32,
                                     0x01, 0xFF,])
    }


    func testGetMeasurementTimingBudget() {
        i2c.written = []
        i2c.expectRead = [187, 3, 15, 5, 28, 4, 5, 7]


        XCTAssertEqual(vl53l0x.getMeasurementTimingBudget(), 15433)
        XCTAssertEqual(i2c.written, [0x01, 0x50, 0x46, 0x51, 0x70, 0x71])
    }


    func testSetMeasurementTimingBudget() {
        i2c.written = []
        i2c.expectRead = [187, 3, 15, 5, 28, 4, 5, 7]

        vl53l0x.setMeasurementTimingBudget(7000)
        XCTAssertEqual(i2c.written, [0x01, 0x50, 0x46, 0x51, 0x70, 0x71, 0x71, 0, 18])
    }

    func testCalTimeoutMclks() {
        XCTAssertEqual(vl53l0x.calTimeoutMclks(2890, 28), 27)
    }

    func testEncodeTimeout() {
        XCTAssertEqual(vl53l0x.encodeTimeout(28064), [7, 219])
    }

    func testGetSequenceStepTimeouts() {
        i2c.written = []
        i2c.expectRead = [3, 15, 5, 28, 4, 5, 7]

        let values = vl53l0x.getSequenceStepTimeouts(false)

        XCTAssertEqual(values.msrcDssTccUs, 488)
        XCTAssertEqual(values.preRangeMclks, 897)
        XCTAssertEqual(values.preRangeUs, 27363)
        XCTAssertEqual(values.finalRangePclks, 10)
        XCTAssertEqual(values.finalRangeUs, 8579)
        XCTAssertEqual(i2c.written, [0x50, 0x46, 0x51, 0x70, 0x71])
    }


    func testDecodeTimeout() {
        XCTAssertEqual(vl53l0x.decodeTimeout(msb: 5, lsb: 28), 897)
    }

    func testGetVcselPulsePeriod() {
        i2c.written = []
        i2c.expectRead = [3]

        XCTAssertEqual(vl53l0x.getVcselPulsePeriod(.finalRange), 8)
        XCTAssertEqual(i2c.written, [0x70])
    }

    func testCalTimeoutUs() {
        XCTAssertEqual(vl53l0x.calTimeoutUs(10, 1), 38)
    }



    func testGetSequenceStepEnables() {
        i2c.written = []
        i2c.expectRead = [123]

        let values = vl53l0x.getSequenceStepEnables()

        XCTAssertEqual(values.tcc, true)
        XCTAssertEqual(values.dss, true)
        XCTAssertEqual(values.msrc, false)
        XCTAssertEqual(values.preRange, true)
        XCTAssertEqual(values.finalRange, false)
        XCTAssertEqual(i2c.written, [0x01])
    }

    

    func testSetGpioConfig() {
        i2c.written = []
        i2c.expectRead = [20]

        vl53l0x.setGpioConfig()
        XCTAssertEqual(i2c.written, [0x0A, 0x04, 0x84, 0x84, 4, 0x0B, 0x01])
    }

    func testLoadTuningSetting() {
        i2c.written = []

        vl53l0x.loadTuningSetting()
        XCTAssertEqual(i2c.written, [0xFF, 0x01, 0x00, 0x00, 0xFF, 0x00, 0x09, 0x00,
                                     0x10, 0x00, 0x11, 0x00, 0x24, 0x01, 0x25, 0xFF,
                                     0x75, 0x00, 0xFF, 0x01, 0x4E, 0x2C, 0x48, 0x00,
                                     0x30, 0x20, 0xFF, 0x00, 0x30, 0x09, 0x54, 0x00,
                                     0x31, 0x04, 0x32, 0x03, 0x40, 0x83, 0x46, 0x25,
                                     0x60, 0x00, 0x27, 0x00, 0x50, 0x06, 0x51, 0x00,
                                     0x52, 0x96, 0x56, 0x08, 0x57, 0x30, 0x61, 0x00,
                                     0x62, 0x00, 0x64, 0x00, 0x65, 0x00, 0x66, 0xA0,
                                     0xFF, 0x01, 0x22, 0x32, 0x47, 0x14, 0x49, 0xFF,
                                     0x4A, 0x00, 0xFF, 0x00, 0x7A, 0x0A, 0x7B, 0x00,
                                     0x78, 0x21, 0xFF, 0x01, 0x23, 0x34, 0x42, 0x00,
                                     0x44, 0xFF, 0x45, 0x26, 0x46, 0x05, 0x40, 0x40,
                                     0x0E, 0x06, 0x20, 0x1A, 0x43, 0x40, 0xFF, 0x00,
                                     0x34, 0x03, 0x35, 0x44, 0xFF, 0x01, 0x31, 0x04,
                                     0x4B, 0x09, 0x4C, 0x05, 0x4D, 0x04, 0xFF, 0x00,
                                     0x44, 0x00, 0x45, 0x20, 0x47, 0x08, 0x48, 0x28,
                                     0x67, 0x00, 0x70, 0x04, 0x71, 0x01, 0x72, 0xFE,
                                     0x76, 0x00, 0x77, 0x00, 0xFF, 0x01, 0x0D, 0x01,
                                     0xFF, 0x00, 0x80, 0x01, 0x01, 0xF8, 0xFF, 0x01,
                                     0x8E, 0x01, 0x00, 0x01, 0xFF, 0x00, 0x80, 0x00])
    }

    

    func testSetSpad() {
        i2c.written = []
        i2c.expectRead = [0, 0, 1, 138, 37,
                          10, 20, 30, 40, 50, 60]

        vl53l0x.setSpad()
        XCTAssertEqual(i2c.written, [0x80, 0x01, 0xFF, 0x01, 0x00, 0x00, 0xFF, 0x06,
                                     0x83, 0x83, 0x04, 0xFF, 0x07, 0x81, 0x01, 0x80, 0x01,
                                     0x94, 0x6b, 0x83, 0x00, 0x83, 0x83,
                                     0x83, 0x01, 0x92,
                                     0x81, 0x00, 0xFF, 0x06, 0x83, 0x83, 33,
                                     0xFF, 0x01, 0x00, 0x01, 0xFF, 0x00, 0x80, 0x00,
                                     0xB0, 0xFF, 0x01, 0x4F, 0, 0x4E, 0x2C, 0xFF, 0, 0xB6, 0xB4,
                                     0xB0, 0, 16, 30, 40, 50, 0])
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

    func testPerformRefCalibration() {
        i2c.written = []
        i2c.expectRead = [1, 1]

        vl53l0x.performRefCalibration()
        XCTAssertEqual(i2c.written, [0x01, 0x01,
                                     0, 0x41, 0x13, 0x0B, 0x01, 0, 0,
                                     0x01, 0x02,
                                     0, 1, 0x13, 0x0B, 0x01, 0, 0,
                                     0x01, 0xE8
                                    ])
    }

    func testPerformSingleRefCalibration() {
        i2c.written = []
        i2c.expectRead = [1]

        vl53l0x.performSingleRefCalibration(10)
        XCTAssertEqual(i2c.written, [0, 11, 0x13, 0x0B, 0x01, 0, 0])
    }


    func testStartContinuous() {
        i2c.written = []
        i2c.expectRead = [1, 2]

        vl53l0x.startContinuous()
        XCTAssertEqual(i2c.written, [0x80, 0x01, 0xFF, 0x01, 0x00, 0x00, 0x91, 2,
                                     0x00, 0x01, 0xFF, 0x00, 0x80, 0x00, 0x00, 0x02,
                                    0x00, 0x00])
    }

    func testStopContinuous() {
        i2c.written = []

        vl53l0x.stopContinuous()
        XCTAssertEqual(i2c.written, [0x00, 0x01, 0xFF, 0x01,
                                     0x00, 0x00, 0x91, 0x00,
                                     0x00, 0x01, 0xFF, 0x00])
    }


    func testReadRangeContinuous() {
        i2c.written = []
        i2c.expectRead = [7, 50, 33]

        XCTAssertEqual(vl53l0x.readRangeContinuous(), 12833)
        XCTAssertEqual(i2c.written, [0x13, 30, 0x0B, 0x01])
    }

    func testReadRangeSingle() {
        i2c.written = []
        i2c.expectRead = [0, 7, 50, 33]

        XCTAssertEqual(vl53l0x.readRangeSingle(), 12833)
        XCTAssertEqual(i2c.written, [0x80, 0x01, 0xFF, 0x01,
                                     0x00, 0x00, 0x91, 0x02,
                                     0x00, 0x01, 0xFF, 0x00,
                                     0x80, 0x00, 0x00, 0x00,
                                     0x00,
                                     0x13, 30, 0x0B, 0x01])
    }
}




