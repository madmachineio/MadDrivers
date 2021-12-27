//=== ADXL345.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 11/21/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for ADXL345 3-axis accelerometer.
///
/// The sensor supports I2C and SPI protocol. You can choose either of them
/// when initializing the sensor.
///
/// The acceleration describes the change of velocity with time, usually
/// measured in m/s^2. The sensor measures it by detecting the force. It can
/// sense gravity and measure inertial force caused by movement. They will
/// change the internal capacitance of the sensor, thus changing the voltage
/// in the circuit.
///
/// The acceleration here is represented in gravitational acceleration or g,
/// which is 9.8m/s^2, e.g. if the sensor is face-up on the table, the z axis
/// acceleration should be close to 1. The sensor provides four sensitivity
/// ranges: ±2, ±4, ±8, or ±16g.
final public class ADXL345 {
    private let i2c: I2C?
    private let address: UInt8?
    private let spi: SPI?
    private let csPin: DigitalOut?

    private var gRange: GRange
    private let gScaleFactor: Float = 0.004
    private var dataRate: DataRate

    private var readBuffer = [UInt8](repeating: 0, count: 6)

    /// Initialize the sensor using I2C communication. The g range is set to
    /// ±2g and the data rate is 100Hz by default.
    /// And the sensor supports standard (100 kHz) and fast (400 kHz) i2c speed.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   The maximum I2C speed is 400KHz.
    ///   - address: **OPTIONAL** The device address of the sensor. 0x53 by default.
    public init(_ i2c: I2C, address: UInt8 = 0x53) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": ADXL345 only supports 100kbps and 400kbps I2C speed")
        }

        self.i2c = i2c
        self.address = address
        self.spi = nil
        self.csPin = nil

        dataRate = .hz100
        gRange = .g2

        guard getDeviceID() == 0xE5 else {
            fatalError(#function + ": cann't find ADXL345 at address \(address)")
        }

        setDataRate(dataRate)
        setRange(gRange)

        // Start to measure.
        try? writeRegister(.powerCTL, 0x08)
        // Disable the interrupt.
        try? writeRegister(.intEnable, 0x00)
    }

    /// Initialize the sensor using SPI communication. The measurement range
    /// is set to ±2g and the data rate is 100Hz by default.
    ///
    /// - Parameters:
    ///   - spi: **REQUIRED** The SPI interface that the sensor connects.
    ///   The maximum SPI clock speed is **5MHz**. Both of the **CPOL and CPHA**
    ///   should be **true**.
    ///   - csPin: **OPTIONAL** The cs pin for the spi. If you set the cs when
    ///   initializing the spi interface, `csPin` should be nil. If not, you
    ///   need to set a digital output pin as the cs pin. And the mode of the pin
    ///   should be **pushPull**.
    public init(_ spi: SPI, csPin: DigitalOut? = nil) {
        self.spi = spi
        self.csPin = csPin
        self.i2c = nil
        self.address = nil

        csPin?.high()

        // Set the data rate as 100hz.
        dataRate = .hz100
        // Set 2g as default g range.
        gRange = .g2

        guard (spi.cs == false && csPin != nil && csPin!.getMode() == .pushPull)
                || (spi.cs == true && csPin == nil) else {
                    fatalError(#function + ": csPin isn't correctly configured")
        }

        guard spi.getMode() == (true, true, .MSB) else {
            fatalError(#function + ": spi mode doesn't match for ADXL345")
        }

        guard spi.getSpeed() <= 5_000_000 else {
            fatalError(#function + ": cannot support spi speed faster than 5MHz")
        }

        guard getDeviceID() == 0xE5 else {
            fatalError(#function + ": cann't find ADXL345 via spi bus")
        }

        setDataRate(dataRate)
        setRange(gRange)

        // Start to measure.
        try? writeRegister(.powerCTL, 0x08)
        // Disable the interrupt.
        try? writeRegister(.intEnable, 0x00)
    }


    /// Read x, y, z acceleration values represented in g (9.8m/s^2)
    /// within the selected range.
    /// - Returns: 3 float within the selected g range.
    public func readValues() -> (x: Float, y: Float, z: Float) {
        let rawValues = readRawValues()

        let x = Float(rawValues.x) * gScaleFactor
        let y = Float(rawValues.y) * gScaleFactor
        let z = Float(rawValues.z) * gScaleFactor
        return (x, y, z)
    }

    /// Read the acceleration on x-axis represented in g (9.8m/s^2)
    /// within the selected range.
    /// - Returns: A float representing the x-axis acceleration.
    public func readX() -> Float {
        try? readRegister(.dataX0, into: &readBuffer, count: 2)
        let x = Float(Int16(readBuffer[0]) | (Int16(readBuffer[1]) << 8))
        return x * gScaleFactor
    }

    /// Read the acceleration on y-axis represented in g (9.8m/s^2)
    /// within the selected range.
    /// - Returns: A float representing the y-axis acceleration.
    public func readY() -> Float {
        try? readRegister(.dataY0, into: &readBuffer, count: 2)
        let y = Float(Int16(readBuffer[0]) | (Int16(readBuffer[1]) << 8))
        return y * gScaleFactor
    }

    /// Read the acceleration on z-axis represented in g (9.8m/s^2)
    /// within the selected range.
    /// - Returns: A float representing the z-axis acceleration.
    public func readZ() -> Float {
        try? readRegister(.dataZ0, into: &readBuffer, count: 2)
        let z = Float(Int16(readBuffer[0]) | (Int16(readBuffer[1]) << 8))
        return z * gScaleFactor
    }

    /// Get the selected g range for the measurement.
    /// - Returns: The current GRange: ±2, ±4, ±8, or ±16g
    public func getRange() -> GRange {
        var byte: UInt8 = 0
        try? readRegister(.dataFormat, into: &byte)
        return GRange(rawValue: byte & 0b0011)!
    }

    /// Set the g range of the sensor.
    /// The supported ranges are ±2, ±4, ±8 and ±16g.
    /// - Parameter gRange: The selected GRange.
    public func setRange(_ gRange: GRange) {
        var byte: UInt8 = 0
        try? readRegister(.dataFormat, into: &byte)

        let value = (byte & 0b1111_0000) | gRange.rawValue | 0b1000
        try? writeRegister(.dataFormat, value)
    }

    /// Get the device ID from the sensor to make sure if the sensor is connected.
    /// The ID you read from the device should be 0xE5.
    /// - Returns: The device ID.
    public func getDeviceID() -> UInt8 {
        var byte: UInt8 = 0
        try? readRegister(.devID, into: &byte)
        return byte
    }

    /// Get current data rate.
    /// - Returns: The specified data rate.
    public func getDataRate() -> DataRate {
        var byte: UInt8 = 0
        try? readRegister(.bwRate, into: &byte)
        return DataRate(rawValue: byte & 0b1111)!
    }

    /// Set the data rate of the sensor. The rate is from 0.1 to 3200Hz.
    /// - Parameter dataRate: The new data rate defined in `DataRate`.
    public func setDataRate(_ dataRate: DataRate) {
        try? writeRegister(.bwRate, dataRate.rawValue)
    }

    /// The output data rate of the sensor. The default rate is 100Hz.
    ///
    /// The data rate will effect the power consumption of the device.
    /// It should be appropriate for the communication protocol and frequency.
    /// A high output data rate with a low communication speed may cause samples
    /// to be discarded.
    public enum DataRate: UInt8 {
        case hz3200 = 0b1111
        case hz1600 = 0b1110
        case hz800 = 0b1101
        case hz400 = 0b1100
        case hz200 = 0b1011
        // The default data rate.
        case hz100 = 0b1010
        case hz50 = 0b1001
        case hz25 = 0b1000
        case hz12_5 = 0b0111
        case hz6_25 = 0b0110
        case hz3_13 = 0b0101
        case hz1_56 = 0b0100
        case hz0_78 = 0b0011
        case hz0_39 = 0b0010
        case hz0_20 = 0b0001
        case hz0_10 = 0b0000
    }

    /// The ranges of the measurement.
    public enum GRange: UInt8 {
        /// The acceleration is from -2g to 2g. It is the default setting.
        case g2 = 0b00
        /// The acceleration is from -4g to 4g.
        case g4 = 0b01
        /// The acceleration is from -8g to 8g.
        case g8 = 0b10
        /// The acceleration is from -16g to 16g.
        case g16 = 0b11
    }
}

extension ADXL345 {
    private func readRawValues() -> (x: Int16,y: Int16, z: Int16) {
        try? readRegister(.dataX0, into: &readBuffer, count: 6)

        let x = Int16(readBuffer[0]) | (Int16(readBuffer[1]) << 8)
        let y = Int16(readBuffer[2]) | (Int16(readBuffer[3]) << 8)
        let z = Int16(readBuffer[4]) | (Int16(readBuffer[5]) << 8)
        return (x, y, z)
    }

    private func writeRegister(_ register: Register, _ value: UInt8) throws {
        var result: Result<(), Errno>

        if i2c != nil {
            result = i2c!.write([register.rawValue, value], to: address!)
        } else {
            csPin?.low()
            result = spi!.write([register.rawValue, value])
            csPin?.high()
        }

        if case .failure(let err) = result {
            throw err
        }
    }

    private func readRegister(
    _ register: Register, into byte: inout UInt8
    ) throws {
        var result: Result<(), Errno>
        var byte: UInt8 = 0

        if let i2c = i2c {
            result = i2c.write(register.rawValue, to: address!)
            if case .failure(let err) = result {
                throw err
            }

            result = i2c.read(into: &byte, from: address!)
            if case .failure(let err) = result {
                throw err
            }
        } else if let spi = spi {
            let register = 0b1000_0000 | register.rawValue
            csPin?.low()

            result = spi.write(register)
            if case .failure(let err) = result {
                throw err
            }

            result = spi.read(into: &byte)
            if case .failure(let err) = result {
                throw err
            }

            csPin?.high()
        }
    }

    private func readRegister(
        _ register: Register, into buffer: inout [UInt8], count: Int
    ) throws {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        var result: Result<(), Errno>
        if let i2c = i2c {
            result = i2c.write(register.rawValue, to: address!)
            if case .failure(let err) = result {
                throw err
            }

            result = i2c.read(into: &buffer, count: count, from: address!)
            if case .failure(let err) = result {
                throw err
            }
        } else if let spi = spi {
            let register = 0b1100_0000 | register.rawValue
            csPin?.low()

            result = spi.write(register)
            if case .failure(let err) = result {
                throw err
            }

            result = spi.read(into: &buffer, count: count)
            if case .failure(let err) = result {
                throw err
            }

            csPin?.high()
        }
    }

    private enum Register: UInt8 {
        case powerCTL = 0x2D
        case intEnable = 0x2E
        case dataX0 = 0x32
        case dataX1 = 0x33
        case dataY0 = 0x34
        case dataY1 = 0x35
        case dataZ0 = 0x36
        case dataZ1 = 0x37
        case dataFormat = 0x31
        case bwRate = 0x2C
        case devID = 0x00
    }
}
