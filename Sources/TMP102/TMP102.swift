//=== TSL2591.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Jan Anstipp
// Created: 09/23/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO


/// The **TMP102** is a temperature sensor communicating via an I2C interface.

/// The temperature is measured with a resolution of 0.0625°C.  with an accuracy of ±0.5°C. The sensor can monitor the temperature. Monitor if the temperature exceeds a critical temperature.
public class TMP102 {
    private let i2c: I2C
    private let serialBusAddress: SerialBusAddress
    lazy private var configuration: Configuration = readConfig()
    
    /// Initialize a TMP102 Driver.
    ///
    /// - Parameters:
    ///    - ic2: The I2C interface on the board.
    ///    - serialBusAddress: The serial bus address from the chip.
    public init(_ ic2: I2C,_ serialBusAddress: SerialBusAddress = .x48){
        self.i2c = ic2
        self.serialBusAddress = serialBusAddress
    }
    
    /// Read the temperature.
    /// - Returns: Temperature of the sensor.
    public func readCelcius() -> Double{
    
        if(configuration.operationMode == .ONESHOT){
            let oneShotBit: UInt8 = 0b10000000
            var newConfig = configuration.getConfigBytes()
            
            newConfig[0] = newConfig[0] | oneShotBit
            write(newConfig, to: .CONFIG)
            // wait for conversion
            sleep(ms: 24)
        }
        
        return Self.toTemp(configuration.dataFormat, read(.TEMP))
    }

    /// Read the configuration.
    /// - Returns:Configuration of the TMP102.
    public func readConfig() -> Configuration{
        var config = Configuration()
        config.setConfigBytes(read(.CONFIG))
        config.lowTemp = Self.toTemp(config.dataFormat,read(.LOW_TEMP))
        config.hightTemp = Self.toTemp(config.dataFormat, read(.HIGH_TEMP))
        self.configuration = config
        return config
    }
    
    /// Set the configuration.
    /// - Parameter configuration:
    public func setConfig(_ configuration: Configuration) {
        write(configuration.getConfigBytes(), to: .CONFIG)
        write(Self.toData(configuration.dataFormat, configuration.lowTemp), to: .LOW_TEMP)
        write(Self.toData(configuration.dataFormat, configuration.hightTemp), to: .HIGH_TEMP)
        self.configuration = configuration
    }
    
    /// Read alert status.
    /// - Returns: Alert status.
    public func isAlert() -> Bool{
        read(.CONFIG)[1].isBitSet(5) == configuration.alertOutputPolarity.boolValue
    }
    
}

extension TMP102{
    
    /// Is currently performing a temparur conversion
    /// - Returns: Performing a conversion
    func isConversionTempartur() -> Bool{
        let oneShotBit: UInt8 = 0b1000_0000
        return !((read(.CONFIG)[0] & oneShotBit) == oneShotBit)
    }
    
    func read(_ registerAddresse: RegisterAddress) -> [UInt8]{
        var buffer: [UInt8] = [0,0]
        i2c.writeRead(registerAddresse.rawValue, into: &buffer, address: serialBusAddress.rawValue)
        return buffer
    }
    
    func write(_ data: [UInt8],to registerAddresse: RegisterAddress) {
        i2c.write([registerAddresse.rawValue]+data, to: serialBusAddress.rawValue)
    }
    
    static func toTemp(_ dataFormat: DataFormat, _ data: [UInt8]) -> Double{
        let isNegative = data[0].isBitSet(7)
        
        switch(dataFormat){
        case (._12Bit):
            let uint16 = UInt16(data[0]) << 4 | UInt16(data[1] >> 4)  | ( isNegative ? 0xF000 : 0 )
            return Double(Int16(bitPattern: uint16)) / 16
        case (._13Bit):
            let uint16 = UInt16(data[0]) << 5 | UInt16(data[1] >> 3) | ( isNegative ? 0xE000 : 0 )
            return Double(Int16(bitPattern: uint16)) / 16
        }
    }
    
    static func toData(_ dataFormat: DataFormat, _ temp: Double) -> [UInt8]{
        let uint16 = UInt16(bitPattern: Int16(temp * 16))
        
        switch(dataFormat){
        case (._12Bit): return [ UInt8(uint16 >> 4 & 0xFF), UInt8(uint16 << 4 & 0xFF) ]
        case (._13Bit): return [ UInt8(uint16 >> 5 & 0xFF), UInt8(uint16 << 3 & 0xFF) ]
        }
    }
}


extension UInt8{
    func isBitSet(_ index: Int) -> Bool{
        (self & (1 << index)) != 0
    }
}
