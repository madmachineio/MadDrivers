import SwiftIO
import XCTest
@testable import MLX90393

final class MLX90393Tests: XCTestCase {
    private var i2c: I2C!
    private var mlx90393: MLX90393!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)
        i2c.expectRead = [0, 0, 0b1111_1101, 0b0101_1111, 0,
                          0, 0b1111_1101, 0b0101_0011, 0,
                          0, 0b1111_1101, 0b0101_0011, 0, 0]

        mlx90393 = MLX90393(i2c)

    }

    func testReset() {
        i2c.written = []
        i2c.expectRead = [0]

        mlx90393.reset()
        XCTAssertEqual(i2c.written, [0b11110000])
    }

    func testCalculateValue() {
        XCTAssertEqual(mlx90393.calculateRaw(.resolution19, msb: 0x40, lsb: 1), 1)
        XCTAssertEqual(mlx90393.calculateRaw(.resolution18, msb: 0x80, lsb: 1), 1)
        XCTAssertEqual(mlx90393.calculateRaw(.resolution17, msb: 0, lsb: 1), 1)

        XCTAssertEqual(mlx90393.calculateRaw(.resolution19, msb: 0b0011_1111, lsb: 0xFF), -1)
        XCTAssertEqual(mlx90393.calculateRaw(.resolution18, msb: 0b0111_1111, lsb: 0xFF), -1)
        XCTAssertEqual(mlx90393.calculateRaw(.resolution17, msb: 0xFF, lsb: 0xFF), -1)
    }

    func testReadXYZ() {
        i2c.written = []
        
        mlx90393.xResolution = .resolution16
        mlx90393.yResolution = .resolution16
        mlx90393.zResolution = .resolution16
        mlx90393.gain = .x4

        i2c.expectRead = [0, 0, 0x01, 0x02, 0x10, 0x11, 0x20, 0x21]
        var xyz = mlx90393.readXYZ()
        XCTAssertEqual(xyz.x, 155.058)
        XCTAssertEqual(xyz.y, 2471.913)
        XCTAssertEqual(xyz.z, 7961.8)
        XCTAssertEqual(i2c.written, [0b111110, 0b1001110])


        mlx90393.xResolution = .resolution18
        mlx90393.yResolution = .resolution18
        mlx90393.zResolution = .resolution18
        mlx90393.gain = .x1_33

        i2c.written = []
        i2c.expectRead = [0, 0, 0xF0, 0xA4, 0xC0, 0x40, 0xA3, 0x20]
        xyz = mlx90393.readXYZ()
        XCTAssertEqual(xyz.x, 23097.636)
        XCTAssertEqual(xyz.y, 13174.848)
        XCTAssertEqual(xyz.z, 11608.672)
        XCTAssertEqual(i2c.written, [0b111110, 0b1001110])

    }

    func testSetResolution() {
        i2c.written = []
        i2c.expectRead = [0, 0b1111_1101, 0b0101_1111, 0]
        mlx90393.setResolution(x: .resolution17, y: .resolution18, z: .resolution19)
        XCTAssertEqual(i2c.written, [0x50, 0b1000,
                                     0x60, 0b1111_1111, 0b0011_1111, 0b1000])

        i2c.written = []
        i2c.expectRead = [0, 0b1111_1011, 0b0011_1111, 0]
        mlx90393.setResolution(x: .resolution16, y: .resolution19, z: .resolution17)
        XCTAssertEqual(i2c.written, [0x50, 0b1000,
                                     0x60, 0b1111_1011, 0b1001_1111, 0b1000])
    }

    func testSetFilter() {
        i2c.written = []
        i2c.expectRead = [0, 0b1111_1101, 0b0101_0011, 0]

        mlx90393.setFilter(.filter3)
        XCTAssertEqual(i2c.written, [0x50, 0b1000, 0x60, 0b1111_1101, 0b0100_1111, 0b1000])

        i2c.written = []
        i2c.expectRead = [0, 0b1111_1101, 0b0101_0011, 0]

        mlx90393.setFilter(.filter5)
        XCTAssertEqual(i2c.written, [0x50, 0b1000, 0x60, 0b1111_1101, 0b0101_0111, 0b1000])
    }

    func testSetOversampling() {
        i2c.written = []
        i2c.expectRead = [0, 0b1111_1101, 0b0101_0011, 0]

        mlx90393.setOversampling(.osr1)
        XCTAssertEqual(i2c.written, [0x50, 0b1000, 0x60, 0b1111_1101, 0b0101_0001, 0b1000])

        i2c.written = []
        i2c.expectRead = [0, 0b1111_1101, 0b0101_0011, 0]

        mlx90393.setOversampling(.osr2)
        XCTAssertEqual(i2c.written, [0x50, 0b1000, 0x60, 0b1111_1101, 0b0101_0010, 0b1000])
    }

    func testSetGain() {
        i2c.written = []
        i2c.expectRead = [0]

        mlx90393.setGain(.x2_5)
        XCTAssertEqual(i2c.written, [0x60, 0x00, 0x3C, 0x00])

        i2c.written = []
        i2c.expectRead = [0]

        mlx90393.setGain(.x4)
        XCTAssertEqual(i2c.written, [0x60, 0x00, 0x1C, 0x00])
    }

    

}
