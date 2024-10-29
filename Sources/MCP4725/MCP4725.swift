//=== MCP4725.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Andy Liu
// Created: 02/25/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for MCP4725 12-bit DAC (digital to analog converter).
///
/// You can use I2C to control it in order to get different output from 0
/// to reference voltage.
///
/// The chip contains an EEROM. If you store the defined output voltage to it,
/// the device can automatically output the same voltage next time
/// it starts to work.
///
/// - Attention: The device address may be different depending on the
/// hardware module. Here are some possible addresses:
/// 0x60, 0x61, 0x62, 0x63, 0x64, 0x65.
final public class MCP4725 {
    private enum WriteType: UInt8 {
        case writeDAC = 0x40
        case writeBothDACEEROM = 0x60
    }
    
    private let i2c: I2C
    private let referenceVoltage: Double
    
    private let address: UInt8
    private let maxRawValue = Int(4095)

    private var readBuffer = [UInt8](repeating: 0, count: 5)
    
    /// Initialize the device. Use the specified I2C bus and
    /// send the device address to get ready for the following communication.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface for the communication.
    ///   - address: **OPTIONAL** The device address. It has a default value
    ///     and you can change it according to your device.
    ///   - referenceVoltage: **OPTIONAL** The reference voltage of your board.
    ///     3.3 by default.
    ///   - outputVoltage: **OPTIONAL** The output voltage.
    ///     If you don’t set it, the device will output 0 volt by default.
    public init(_ i2c: I2C, address: UInt8 = 0x60,
                referenceVoltage: Double = 3.3, outputVoltage: Double? = nil) {
        self.i2c = i2c
        self.address = address
        self.referenceVoltage = referenceVoltage
        if let voltage = outputVoltage {
            setOutputVoltage(voltage)
        } else {
            setOutputVoltage(0.0)
        }
    }
    
    /// Read from the device to get current output voltage. It is a Double.
    /// - Returns: Current output voltage.
    public func getOutputVoltage() -> Double {
        return Double(getOutputValue()) / Double(maxRawValue) * referenceVoltage
    }
    
    /// Read from the device to get the raw value of the DAC.
    /// - Returns: DAC raw value
    public func getOutputRawValue() -> Int {
        return Int(getOutputValue())
    }
    
    /// Set a raw value to the device to output the determined voltage.
    /// The value is between 0 and 4095.
    /// - Parameters:
    ///   - newValue: The raw value sent to the device.
    ///   - writeToEEROM: Whether EEROM will store the value.
    ///     By default, it won't.
    public func setRawValue(_ newValue: Int, writeToEEROM: Bool = false) {
        guard newValue >= 0 && newValue <= maxRawValue else {
            print("value \(newValue) is not acceptable!")
            return
        }
        
        let value = UInt16(newValue)
        var data = [UInt8](repeating: 0x00, count: 3)
        
        if writeToEEROM {
            data[0] = WriteType.writeBothDACEEROM.rawValue
        } else {
            data[0] = WriteType.writeDAC.rawValue
        }
        
        data[1] = UInt8((value & 0x0FF0) >> 4)
        data[2] = UInt8((value & 0x000F) << 4)
        
        try? writeValue(data)
    }
    
    /// Set the output voltage. The value is between 0 and reference voltage.
    /// - Parameters:
    ///   - voltage: The voltage the device will output.
    ///   - writeToEEROM: Whether EEROM will store the value.
    ///     By default, it won't.
    public func setOutputVoltage(_ voltage: Double,
                                 writeToEEROM: Bool = false) {
            func getDoubleString(_ num: Double) -> String {
                let int = Int(num)
                let frac = Int((num - Double(int)) * 100)
                return "\(int).\(frac)"
            }
        guard voltage >= 0.0 && voltage <= referenceVoltage else {

            print("voltage \(getDoubleString(voltage)) is not acceptable!")
            return
        }
        
        let value = UInt16(voltage / referenceVoltage * Double(maxRawValue))
        var data = [UInt8](repeating: 0x00, count: 3)
        
        if writeToEEROM {
            data[0] = WriteType.writeBothDACEEROM.rawValue
        } else {
            data[0] = WriteType.writeDAC.rawValue
        }
        
        data[1] = UInt8((value & 0x0FF0) >> 4)
        data[2] = UInt8((value & 0x000F) << 4)
        
        try? writeValue(data)
    }
    
    /// Set a series of voltage values to the device to obtain varying voltages.
    /// The value is between 0 and reference voltage.
    /// - Parameter voltages: Voltage values stored in an array.
    public func fastWrite(_ voltages: [Double]) {
        var data = [UInt8](repeating: 0x00, count: voltages.count * 2)
        
        for index in 0..<voltages.count {
            let value = UInt16(
                voltages[index] / referenceVoltage * Double(maxRawValue))
            data[index * 2] = UInt8(value >> 8)
            data[index * 2 + 1] = UInt8(value & 0xFF)
        }

        try? writeValue(data)
    }
}


extension MCP4725 {
    private func getEEROMValue() -> UInt16 {
        try? readValue(into: &readBuffer)

        let high = UInt16(readBuffer[3] & 0x0F) << 8
        let low = UInt16(readBuffer[4])
        
        return high | low
    }
    
    private func getOutputValue() -> UInt16 {
        try? readValue(into: &readBuffer)

        let high = UInt16(readBuffer[1] & 0xF0) << 4
        let low = (UInt16(readBuffer[1] & 0x0F) << 4) |
        (UInt16(readBuffer[2] & 0xF0) >> 4)
        
        return high | low
    }

    private func readValue(into buffer: inout [UInt8]) throws(Errno) {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        let result = i2c.read(into: &buffer, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func writeValue(_ data: [UInt8]) throws(Errno) {
        let result = i2c.write(data, to: address)
        if case .failure(let err) = result {
            throw err
        }
    }
}
