//=== ADXL345.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 11/21/2021
// Updated: 11/24/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for the ADXL345 3-axis accelerometer.
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
/// The acceleration that the sensors reads is represented in g (9.8m/s^2).
/// If the sensor is face-up on the table, the acceleration on the z-axis
/// should be close to 1.
///
/// The sensor provides four ranges: ±2, ±4, ±8, or ±16g.
/// The accelerations can be positive or negative. You may notice the note
/// on your sensor that indicates the positive x, y, z-direction.
final public class ADXL345 {
    private let i2c: I2C?
    private let address: UInt8?
    private let spi: SPI?

    private var gRange: GRange
    private let gScaleFactor: Float = 0.004
    private var dataRate: DataRate


    /// Initialize the sensor using I2C communication. The g range will be
    /// set to ±2g and the data rate will be 100Hz by default.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   - address: **OPTIONAL** The device address of the sensor.
    public init(_ i2c: I2C, address: UInt8 = 0x53) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": ADXL345 only supports 100kbps and 400kbps I2C speed")
        }

        self.i2c = i2c
        self.address = address
        self.spi = nil

        dataRate = .hz100
        gRange = .g2

        guard let deviceId = getDeviceID(), deviceId == 0xE5 else {
            fatalError(#function + ": ADXL345 not connected")
        }

        setDataRate(dataRate)
        setRange(gRange)

        // Start to measure.
        writeRegister(.powerCTL, 0x08)
        // Disable the interrupt.
        writeRegister(.intEnable, 0x00)
    }

    /*
     /// Initialize the sensor using SPI communication. The maximum SPI clock
     /// speed is 5 MHz.
    public init(_ spi: SPI) {
        self.spi = spi
        self.i2c = nil
        self.address = nil


        // Set the data rate as 100hz.
        dataRate = .hz800
        // Set 2g as default g range.
        gRange = .g2


        setDataRate(dataRate)
        setRange(gRange)


        // Start to measure.
        writeRegister(.powerCTL, 0x08)
        // Disable the interrupt.
        writeRegister(.intEnable, 0x00)
    }
     */

    /// Read x, y, z acceleration values represented in g (9.8m/s^2)
    /// within the selected range.
    /// - Returns: 3 float within the selected g range.
    public func readValues() -> (x: Float, y: Float, z: Float)? {
        let rawValues = readRawValues()
        var values: (x: Float, y: Float, z: Float)? = nil

        if let rawValues = rawValues {
            let x = Float(rawValues.x) * gScaleFactor
            let y = Float(rawValues.y) * gScaleFactor
            let z = Float(rawValues.z) * gScaleFactor
            values = (x, y, z)
        }

        return values
    }

    /// Read the acceleration on x-axis represented in g (9.8m/s^2)
    /// within the selected range.
    /// - Returns: A float representing the acceleration.
    public func readX() -> Float? {
        let rawX = readRegister(.dataX0, count: 2)
        var x: Float? = nil

        if rawX.count == 2 {
            x = Float(Int16(rawX[0]) | (Int16(rawX[1]) << 8)) * gScaleFactor
        }

        return x
    }

    /// Read the acceleration on y-axis represented in g (9.8m/s^2)
    /// within the selected range.
    /// - Returns: A float representing the acceleration.
    public func readY() -> Float? {
        let rawY = readRegister(.dataY0, count: 2)
        var y: Float? = nil

        if rawY.count == 2 {
            y = Float(Int16(rawY[0]) | (Int16(rawY[1]) << 8)) * gScaleFactor
        }

        return y
    }

    /// Read the acceleration on z-axis represented in g (9.8m/s^2)
    /// within the selected range.
    /// - Returns: A float representing the acceleration.
    public func readZ() -> Float? {
        let rawZ = readRegister(.dataZ0, count: 2)
        var z: Float? = nil

        if rawZ.count == 2 {
            z = Float(Int16(rawZ[0]) | (Int16(rawZ[1]) << 8)) * gScaleFactor
        }

        return z
    }

    /// Get the selected g range for the measurement.
    /// - Returns: The current GRange: ±2, ±4, ±8, or ±16g
    public func getRange() -> GRange? {
        let data = readRegister(.dataFormat)
        if let data = data {
            let range = data & 0b0011
            return GRange(rawValue: range)!
        } else {
            print("read range error")
            return nil
        }
    }

    /// Set the g range of the sensor.
    /// The supported ranges are ±2, ±4, ±8 and ±16g.
    /// - Parameter gRange: The selected GRange.
    public func setRange(_ gRange: GRange) {
        let data = readRegister(.dataFormat)
        if let data = data {
            var value = data & 0b1111_0000
            value = value | gRange.rawValue
            value = value | 0b1000
            writeRegister(.dataFormat, value)
        } else {
            print("read range error")
        }
    }

    /// Get the device ID from the sensor to make sure if the sensor is connected.
    /// The ID you read from the device should be 0xE5.
    /// - Returns: The device ID.
    public func getDeviceID() -> UInt8? {
        let data = readRegister(.devID)
        if let data = data {
            return data
        } else {
            print("read devID error")
            return nil
        }
    }

    /// Get current data rate.
    /// - Returns: The specified data rate.
    public func getDataRate() -> DataRate? {
        let data = readRegister(.bwRate)
        if let data = data {
            let dataRate = DataRate(rawValue: data & 0b1111)
            return dataRate
        } else {
            print("read data rate error")
            return nil
        }
    }

    /// Set the data rate of the sensor. The rate is from 0.1 to 3200Hz.
    /// - Parameter dataRate: The new data rate defined in `DataRate`.
    public func setDataRate(_ dataRate: DataRate) {
        writeRegister(.bwRate, dataRate.rawValue)
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
    private func readRawValues() -> (x: Int16,y: Int16, z: Int16)? {
        let rawValues = readRegister(.dataX0, count: 6)
        if rawValues.count == 6 {
            let x = Int16(rawValues[0]) | (Int16(rawValues[1]) << 8)
            let y = Int16(rawValues[2]) | (Int16(rawValues[3]) << 8)
            let z = Int16(rawValues[4]) | (Int16(rawValues[5]) << 8)
            return (x, y, z)
        } else {
            return nil
        }

    }

    private func writeRegister(_ register: Register, _ value: UInt8) {
        if let i2c = i2c {
            i2c.write([register.rawValue, value], to: address!)
        }else if let spi = spi {
            spi.write([register.rawValue, value])
        }
    }

    private func readRegister(_ register: Register) -> UInt8? {
        var data: UInt8? = nil

        if let i2c = i2c {
            i2c.write(register.rawValue, to: address!)
            data = i2c.readByte(from: address!)
        } else if let spi = spi {
            spi.write(register.rawValue)
            data = spi.readByte()
        }

        return data
    }

    private func readRegister(_ register: Register, count: Int) -> [UInt8] {
        var data: [UInt8] = Array(repeating: 0, count: count)

        if let i2c = i2c {
            i2c.write(register.rawValue, to: address!)
            data = i2c.read(count: count, from: address!)
        } else if let spi = spi {
            spi.write(register.rawValue)
            data = spi.read(count: count)
        }

        return data
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
