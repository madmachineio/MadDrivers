import XCTest
import SwiftIO

@testable import TMP102

final class TMP102Tests: XCTestCase {
    
    func testToTemp12Bit(){
        let dataFormat = DataFormat._12Bit
        XCTAssertEqual(127.9375,TMP102.toTemp(dataFormat, [0b0111_1111, 0b1111_0000]))
        XCTAssertEqual(100,TMP102.toTemp(dataFormat, [0b0110_0100, 0b0000_0000]))
        XCTAssertEqual(80,TMP102.toTemp(dataFormat, [0b0101_0000, 0b0000_0000]))
        XCTAssertEqual(75,TMP102.toTemp(dataFormat, [0b0100_1011, 0b0000_0000]))
        XCTAssertEqual(50,TMP102.toTemp(dataFormat, [0b0011_0010, 0b0000_0000]))
        XCTAssertEqual(25,TMP102.toTemp(dataFormat, [0b0001_1001, 0b0000_0000]))
        XCTAssertEqual(0.25,TMP102.toTemp(dataFormat, [0b0000_0000, 0b0100_0000]))
        XCTAssertEqual(0,TMP102.toTemp(dataFormat, [0b0000_0000, 0b0000_0000]))
        XCTAssertEqual(-0.25,TMP102.toTemp(dataFormat, [0b1111_1111, 0b1100_0000]))
        XCTAssertEqual(-25,TMP102.toTemp(dataFormat, [0b1110_0111, 0b0000_0000]))
        XCTAssertEqual(-55,TMP102.toTemp(dataFormat, [0b1100_1001, 0b0000_0000]))
    }
    
    func testToData12Bit(){
        let dataFoamrt = DataFormat._12Bit
        XCTAssertEqual([0b0111_1111, 0b1111_0000],TMP102.toData(dataFoamrt,127.9375))
        XCTAssertEqual([0b0110_0100, 0b0000_0000],TMP102.toData(dataFoamrt,100))
        XCTAssertEqual([0b0101_0000, 0b0000_0000],TMP102.toData(dataFoamrt,80))
        XCTAssertEqual([0b0100_1011, 0b0000_0000],TMP102.toData(dataFoamrt,75))
        XCTAssertEqual([0b0011_0010, 0b0000_0000],TMP102.toData(dataFoamrt,50))
        XCTAssertEqual([0b0001_1001, 0b0000_0000],TMP102.toData(dataFoamrt,25))
        XCTAssertEqual([0b0000_0000, 0b0100_0000],TMP102.toData(dataFoamrt,0.25))
        XCTAssertEqual([0b0000_0000, 0b0000_0000],TMP102.toData(dataFoamrt,0))
        XCTAssertEqual([0b1111_1111, 0b1100_0000],TMP102.toData(dataFoamrt,-0.25))
        XCTAssertEqual([0b1110_0111, 0b0000_0000],TMP102.toData(dataFoamrt,-25))
        XCTAssertEqual([0b1100_1001, 0b0000_0000],TMP102.toData(dataFoamrt,-55))
    }
    
    func testToTemp13Bit(){
        let dataFoamrt =  DataFormat._13Bit
        XCTAssertEqual(150,TMP102.toTemp(dataFoamrt,[0b0100_1011, 0b0000_0000]))
        XCTAssertEqual(128,TMP102.toTemp(dataFoamrt, [0b0100_0000, 0b0000_0000]))
        XCTAssertEqual(127.9375,TMP102.toTemp(dataFoamrt, [0b0011_1111, 0b1111_1000]))
        XCTAssertEqual(100,TMP102.toTemp(dataFoamrt, [0b0011_0010, 0b0000_0000]))
        XCTAssertEqual(80,TMP102.toTemp(dataFoamrt, [0b0010_1000, 0b0000_0000]))
        XCTAssertEqual(75,TMP102.toTemp(dataFoamrt, [0b0010_0101, 0b1000_0000]))
        XCTAssertEqual(50,TMP102.toTemp(dataFoamrt, [0b0001_1001, 0b0000_0000]))
        XCTAssertEqual(25,TMP102.toTemp(dataFoamrt, [0b0000_1100, 0b1000_0000]))
        XCTAssertEqual(0.25,TMP102.toTemp(dataFoamrt, [0b0000_0000, 0b0010_0000]))
        XCTAssertEqual(0,TMP102.toTemp(dataFoamrt, [0b0000_0000, 0b0000_0000]))
        XCTAssertEqual(-0.25,TMP102.toTemp(dataFoamrt, [0b1111_1111, 0b1110_0000]))
        XCTAssertEqual(-25,TMP102.toTemp(dataFoamrt, [0b1111_0011, 0b1000_0000]))
        XCTAssertEqual(-55,TMP102.toTemp(dataFoamrt, [0b1110_0100, 0b1000_0000]))
    }

    func testToData13Bit(){
        let dataFoamrt =  DataFormat._13Bit
        XCTAssertEqual([0b0100_1011, 0b0000_0000],TMP102.toData(dataFoamrt,150))
        XCTAssertEqual([0b0100_0000, 0b0000_0000],TMP102.toData(dataFoamrt,128))
        XCTAssertEqual([0b0011_1111, 0b1111_1000],TMP102.toData(dataFoamrt,127.9375))
        XCTAssertEqual([0b0011_0010, 0b0000_0000],TMP102.toData(dataFoamrt,100))
        XCTAssertEqual([0b0010_1000, 0b0000_0000],TMP102.toData(dataFoamrt,80))
        XCTAssertEqual([0b0010_0101, 0b1000_0000],TMP102.toData(dataFoamrt,75))
        XCTAssertEqual([0b0001_1001, 0b0000_0000],TMP102.toData(dataFoamrt,50))
        XCTAssertEqual([0b0000_1100, 0b1000_0000],TMP102.toData(dataFoamrt,25))
        XCTAssertEqual([0b0000_0000, 0b0010_0000],TMP102.toData(dataFoamrt,0.25))
        XCTAssertEqual([0b0000_0000, 0b0000_0000],TMP102.toData(dataFoamrt,0))
        XCTAssertEqual([0b1111_1111, 0b1110_0000],TMP102.toData(dataFoamrt,-0.25))
        XCTAssertEqual([0b1111_0011, 0b1000_0000],TMP102.toData(dataFoamrt,-25))
        XCTAssertEqual([0b1110_0100, 0b1000_0000],TMP102.toData(dataFoamrt,-55))
    }
    
    func testToTempToData12Bit(){
        let dataFoamrt =  DataFormat._12Bit
        XCTAssertEqual(127.9375, TMP102.toTemp(dataFoamrt,TMP102.toData(dataFoamrt, 127.9375)))
        XCTAssertEqual(100,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 100)))
        XCTAssertEqual(80,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 80)))
        XCTAssertEqual(75,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 75)))
        XCTAssertEqual(50,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 50)))
        XCTAssertEqual(25,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 25)))
        XCTAssertEqual(0.25,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 0.25)))
        XCTAssertEqual(0,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 0)))
        XCTAssertEqual(-0.25,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, -0.25)))
        XCTAssertEqual(-25,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, -25)))
        XCTAssertEqual(-55,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, -55)))
    }
    
    func testToTempToData13Bit(){
        let dataFoamrt = DataFormat._13Bit
        XCTAssertEqual(150, TMP102.toTemp(dataFoamrt,TMP102.toData(dataFoamrt, 150)))
        XCTAssertEqual(128,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 128)))
        XCTAssertEqual(127.9375,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 127.9375)))
        XCTAssertEqual(100,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 100)))
        XCTAssertEqual(80,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 80)))
        XCTAssertEqual(75,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 75)))
        XCTAssertEqual(50,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 50)))
        XCTAssertEqual(25,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 25)))
        XCTAssertEqual(0.25,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 0.25)))
        XCTAssertEqual(0,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, 0)))
        XCTAssertEqual(-0.25,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, -0.25)))
        XCTAssertEqual(-25,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, -25)))
        XCTAssertEqual(-55,TMP102.toTemp(dataFoamrt, TMP102.toData(dataFoamrt, -55)))
    }
}
