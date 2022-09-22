import XCTest
import SwiftIO

@testable import ADT7410

final class ADT7410Tests: XCTestCase {
    
    func testToTemp13Bit(){
        let resulution = ADT7410.Resulution.r_13Bit
        XCTAssertEqual(-55,ADT7410.toTemp(resulution,[0b1110_0100,0b1000_0000]))
        XCTAssertEqual(-50,ADT7410.toTemp(resulution, [0b1110_0111,0b0000_0000]))
        XCTAssertEqual(-25,ADT7410.toTemp(resulution, [0b1111_0011,0b1000_0000]))
        XCTAssertEqual(-0.0625,ADT7410.toTemp(resulution, [0b1111_1111,0b1111_1000]))
        XCTAssertEqual(0,ADT7410.toTemp(resulution, [0b0000_0000,0b0000_0000]))
        XCTAssertEqual(0.0625,ADT7410.toTemp(resulution, [0b0000_0000,0b0000_1000]))
        XCTAssertEqual(25,ADT7410.toTemp(resulution, [0b0000_1100,0b1000_0000]))
        XCTAssertEqual(50,ADT7410.toTemp(resulution, [0b0001_1001,0b0000_0000]))
        XCTAssertEqual(125,ADT7410.toTemp(resulution, [0b0011_1110,0b1000_0000]))
        XCTAssertEqual(150,ADT7410.toTemp(resulution, [0b0100_1011,0b0000_0000]))
    }
    
    func testToData13Bit(){
        let resulution = ADT7410.Resulution.r_13Bit
        XCTAssertEqual([0b1110_0100,0b1000_0000],ADT7410.toData(resulution,-55))
        XCTAssertEqual([0b1110_0111,0b0000_0000],ADT7410.toData(resulution,-50))
        XCTAssertEqual([0b1111_0011,0b1000_0000],ADT7410.toData(resulution,-25))
        XCTAssertEqual([0b1111_1111,0b1111_1000],ADT7410.toData(resulution,-0.0625))
        XCTAssertEqual([0b0000_0000,0b0000_0000],ADT7410.toData(resulution,0))
        XCTAssertEqual([0b0000_0000,0b0000_1000],ADT7410.toData(resulution,0.0625))
        XCTAssertEqual([0b0000_1100,0b1000_0000],ADT7410.toData(resulution,25))
        XCTAssertEqual([0b0001_1001,0b0000_0000],ADT7410.toData(resulution,50))
        XCTAssertEqual([0b0011_1110,0b1000_0000],ADT7410.toData(resulution,125))
        XCTAssertEqual([0b0100_1011,0b0000_0000],ADT7410.toData(resulution,150))
    }
        
    func testDefaultConfiguration(){
        let config = ADT7410.Configuration()
        XCTAssertEqual(0x0, config.getByte())
    }
    
    func testConfigurationNumberOfFaults(){
        var config = ADT7410.Configuration()
        
        config.numberOfFaults = .ONE
        XCTAssertEqual(0b0, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
        
        config.numberOfFaults = .TWO
        XCTAssertEqual(0b1, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
        
        config.numberOfFaults = .THREE
        XCTAssertEqual(0b10, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
        
        config.numberOfFaults = .FOUR
        XCTAssertEqual(0b11, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
    }
    
    func testConfigurationCTPinPolarity(){
        var config = ADT7410.Configuration()
        
        config.ctOutputPolarity = .ACTIVE_LOW
        XCTAssertEqual(0b0, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
        
        config.ctOutputPolarity = .ACTIVE_HIGH
        XCTAssertEqual(0b1 << 2, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
    }
    
    func testConfigurationINTPinPolarity(){
        var config = ADT7410.Configuration()
        
        config.intOutputPolarity = .ACTIVE_LOW
        XCTAssertEqual(0b0, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
        
        config.intOutputPolarity = .ACTIVE_HIGH
        XCTAssertEqual(0b1 << 3, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
    }
    
    func testConfigurationTemperatureDetectionMode(){
        var config = ADT7410.Configuration()
        
        config.temperatureDetectionMode = .COMPARATOR_MODE
        XCTAssertEqual(0b0, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
        
        config.temperatureDetectionMode = .INTERRUPT_MODE
        XCTAssertEqual(0b1 << 4, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
    }
    
    func testConfigurationOperationMode(){
        var config = ADT7410.Configuration()
        
        config.operationMode = .CONTINUOS
        XCTAssertEqual(0b0, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
        
        config.operationMode = .ONE_SHOT
        XCTAssertEqual(0b01 << 5, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
        
        config.operationMode = .SPS
        XCTAssertEqual(0b10 << 5, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
        
        config.operationMode = .SHUTDOWN
        XCTAssertEqual(0b11 << 5, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
    }
    
    func testConfigurationResolution(){
        var config = ADT7410.Configuration()
        
        config.resulution = .r_13Bit
        XCTAssertEqual(0b0, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
        
        config.resulution = .r_16Bit
        XCTAssertEqual(0b1 << 7, config.getByte())
        XCTAssertEqual(config, ADT7410.Configuration(config.getByte()))
    }
    
    
    func testStatus(){
        XCTAssertTrue(!ADT7410.Status(0b0).isWriteTemperaure)
        XCTAssertTrue(!ADT7410.Status(0b0).isTCritInterrupt)
        XCTAssertTrue(!ADT7410.Status(0b0).isTLowInterrupt)
        XCTAssertTrue(!ADT7410.Status(0b0).isTHightInterrupt)

        XCTAssertTrue(ADT7410.Status(0b1 << 4).isTLowInterrupt)
        XCTAssertTrue(ADT7410.Status(0b1 << 5).isTHightInterrupt)
        XCTAssertTrue(ADT7410.Status(0b1 << 6).isTCritInterrupt)
        XCTAssertTrue(ADT7410.Status(0b1 << 7).isWriteTemperaure)
    }
    
    func testisBitSet(){
        XCTAssertTrue(UInt8(0b1).isBitSet(0))
        XCTAssertTrue(!UInt8(0b0).isBitSet(0))
        XCTAssertTrue(UInt8(0b10000).isBitSet(4))
        XCTAssertTrue(!UInt8(0b100000).isBitSet(4))
    }
}

