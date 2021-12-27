//=== VEML6040.swift ------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Andy Liu
// Created: 03/01/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/**
 This is the library for VEML6040 color sensor.
 You can communicate with it using I2C protocol.

 The sensor can measure red, green, blue and white lights. It provides 16-bit
 resolution for each channel. When receiving a reflected light, it can detect
 the intensity of each light. Then you can get the color based on the reading.

 
 - Attention: Our eyes are more sensitive to blue light, while the sensor
 is less sensitive. So the color you see may be unlike that the sensor reads.
 In this case, if you want to use the sensor to detect color, you need to
 normalize the RGB values relative to the white light.
 
 */

final public class VEML6040 {
    
    /// Different choices of integration time to measure the light.
    public enum IntegrationTime: UInt8 {
        case i40ms      = 0
        case i80ms      = 0b0001_0000
        case i160ms     = 0b0010_0000
        case i320ms     = 0b0011_0000
        case i640ms     = 0b0100_0000
        case i1280ms    = 0b0101_0000
    }
    
    /// The sensor's address.
    public let address: UInt8
    /// The I2C interface for the sensor.
    public let i2c: I2C

    private var readBuffer = [UInt8](repeating: 0, count: 2)
    
    /// Get a suitable sensitivity according to the integration time.
    /// A longer time will lead to a higher sensitivity.
    public var sensitivity: Float {
        switch integrationTime {
        case .i40ms:
            return 0.25168
        case .i80ms:
            return 0.12584
        case .i160ms:
            return 0.06292
        case .i320ms:
            return 0.03146
        case .i640ms:
            return 0.01573
        case .i1280ms:
            return 0.007865
        }
    }
    
    /// Get the detectable intensity according to the integration time.
    /// A longer time will lead to a smaller range.
    public var maxLux: Int {
        switch integrationTime {
        case .i40ms:
            return 16496
        case .i80ms:
            return 8248
        case .i160ms:
            return 4124
        case .i320ms:
            return 2062
        case .i640ms:
            return 1031
        case .i1280ms:
            return 515
        }
    }
    
    private var integrationTime: IntegrationTime
    private var configValue: Config
    
    /// Initialize the I2C bus and reset the sensor to prepare for the
    /// following commands. It configures the sensor and set a default
    /// integration time of 160ms.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   - address: **OPTIONAL** The sensor's address. It has a default value.
    public init(_ i2c: I2C, address: UInt8 = 0x10) {
        self.i2c = i2c
        self.address = address
        
        configValue = [.noTrig, .autoMode]
        integrationTime = .i160ms
        
        setIntegrationTime(integrationTime)
    }
    
    /// Set the integration time to adjust the sensitivity of the sensor.
    /// If you choose a longer time, the sensitivity will increase and the
    /// detectable intensity will decrease accordingly.
    /// By default, the time is 160ms.
    /// - Parameter newValue: The new integration time for the sensor.
    ///     You can find it in the enum `IntegrationTime`.
    public func setIntegrationTime(_ newValue: IntegrationTime) {
        integrationTime = newValue
        let newConfig = Config(rawValue: integrationTime.rawValue)
        configValue.remove(.integrationTimeMask)
        configValue.insert(newConfig)
        
        try? writeConfig(configValue)
    }
    
    
    /// Get the current integration time.
    /// - Returns: The integration time.
    public func getIntegrationTime() -> IntegrationTime {
        return integrationTime
    }
    
    /// Read the raw value of red light.
    /// - Returns: Value of red light between 0 and 65535.
    public func readRedRawValue() -> UInt16 {
        try? readRegister(.redData, into: &readBuffer)
        return calUInt16(readBuffer)
    }
    
    /// Read the raw value of green light.
    /// - Returns: Value of green light between 0 and 65535.
    public func readGreenRawValue() -> UInt16 {
        try? readRegister(.greenData, into: &readBuffer)
        return calUInt16(readBuffer)
    }
    
    /// Read the raw value of blue light.
    /// - Returns: Value of blue light between 0 and 65535.
    public func readBlueRawValue() -> UInt16 {
        try? readRegister(.blueData, into: &readBuffer)
        return calUInt16(readBuffer)
    }
    
    /// Read the raw value of white light.
    /// - Returns: Value of white light between 0 and 65535.
    public func readWhiteRawValue() -> UInt16 {
        try? readRegister(.whiteData, into: &readBuffer)
        return (UInt16(readBuffer[1]) << 8) | UInt16(readBuffer[0])
    }
    
    /// Read intensity of the ambient light. The value is measured in lux.
    /// The spectral characteristics of green light matches well to the human
    /// eye. So the ambient light intensity is based on green channel.
    /// - Returns: An integer that represent the intensity in lux.
    public func readAmbientLight() -> Int {
        return Int(Float(readGreenRawValue()) * sensitivity)
    }
}


extension VEML6040 {
    private enum Reg: UInt8 {
        case config = 0x00
        case redData = 0x08
        case greenData = 0x09
        case blueData = 0x0A
        case whiteData = 0x0B
    }
    
    private struct Config: OptionSet {
        let rawValue: UInt8
        
        static let integrationTimeMask = Config(rawValue: 0b0111_0000)
        
        static let noTrig = Config([])
        static let trig = Config(rawValue: 0b0100)
        
        static let autoMode = Config([])
        static let fouceMode = Config(rawValue: 0b10)
        
        static let enable = Config([])
        static let disable = Config(rawValue: 0b1)
        
    }
    
    // Split the 16-bit data into two 8-bit data.
    // Write the data to the default address of the sensor.
    private func writeConfig(_ value: Config) throws {
        let array: [UInt8] = [Reg.config.rawValue, value.rawValue, 0]
        let result = i2c.write(array, to: address)
        if case .failure(let err) = result {
            throw err
        }
    }
    
    private func readRegister(_ reg: Reg, into buffer: inout [UInt8]) throws {
        let result = i2c.writeRead(reg.rawValue, into: &buffer, address: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func calUInt16(_ data: [UInt8]) -> UInt16 {
        return (UInt16(data[1]) << 8) | UInt16(data[0])
    }
}
