import XCTest
import SwiftIO

@testable import MCP9808

final class MCP9808Tests: XCTestCase {
    private var i2c: I2C!
    private var mcp9808: MCP9808!

    override func setUp() {
        super.setUp()

        i2c = I2C(Id.I2C0)
        i2c.expectRead = [0x00, 0x54, 0x04, 0x00]
        
        mcp9808 = MCP9808(i2c)
        
    }

    func testGetId() {
        i2c.written = []
        i2c.expectRead = [0x00, 0x54, 0x04, 0x00]

        let ids = mcp9808.getId()

        XCTAssertEqual(ids.0, 0x0054)
        XCTAssertEqual(ids.1, 0x04)
        XCTAssertEqual(i2c.written, [0x06, 0x07])
    }

    func testReadCelsius() {
        i2c.written = []
        i2c.expectRead = [1, 148]

        XCTAssertEqual(mcp9808.readCelsius(), 25.25)
        XCTAssertEqual(i2c.written, [0x05])
    }


    func testGetResolution() {
        i2c.written = []
        i2c.expectRead = [1]

        XCTAssertEqual(mcp9808.getResolution(), .quarterC)
        XCTAssertEqual(i2c.written, [0x08])
    }


    func testSetResolution() {
        i2c.written = []
        mcp9808.setResolution(.eighthC)
        XCTAssertEqual(i2c.written, [0x08, 2])
    }
}
