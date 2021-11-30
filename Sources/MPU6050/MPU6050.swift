//=== MPU6050.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 11/29/2021
// Updated: 11/29/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for MPU6050 accelerometer and gyroscope.
///
/// The MPU6050 sensor has a gyroscope and an accelerometer on the chip,
/// as well as a temperature sensor.
/// The movement will change the internal structure and lead to capacitance change.
/// The sensor can capture the change and will produce a corresponding voltage.
///
/// The accelerometer can measure the acceleration on x, y and z axes and return
/// the values in m/s^2 or g (9.8m/s^2). The gyroscope can measure the angular
/// velocity on 3 axes. The values are in degree per second.
///
/// The sensor combines the two parts and can thus provides an accurate position
/// information. It provides 16-bit resolution to sample the acceleration and
/// rotation. It communicates with your board using I2C protocol.
final public class MPU6050 {

    private let i2c: I2C
    private let address: UInt8
    private var accelRange: AccelRange
    private var gyroRange: GyroRange

    private var accelSensibility: Float {
        switch accelRange {
        case .g2:
            return 16384
        case .g4:
            return 8192
        case .g8:
            return 4096
        case .g16:
            return 2048
        }
    }

    private var gyroSensibility: Float {
        switch gyroRange {
        case .dps250:
            return 131
        case .dps500:
            return 65.5
        case .dps1000:
            return 32.8
        case .dps2000:
            return 16.4
        }
    }

    /// Initialize the sensor using I2C communication..
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   - address: **OPTIONAL** The device address of the sensor.
    public init(_ i2c: I2C, address: UInt8 = 0x68) {
        self.i2c = i2c
        self.address = address
        accelRange = .g2
        gyroRange = .dps500

        if readRegister(.whoAmI) != 0x68 {
            print("MPU6050 not connected")
        }

        reset()

        // Sets the sample rate.
        writeRegister(.sampleRateDivider, 0)
        // Use X axis gyroscope as the clock reference.
        writeRegister(.powerManagement1, 1)

        setFilterBandwidth(.hz260)
        setGyroRange(gyroRange)
        setAccelRange(accelRange)
        sleep(ms: 100)
    }

    /// Read current temperature.
    /// - Returns: The temperature in Celsius.
    public func readTemperature() -> Float {
        let data = readRegister(.tempOut, count: 2)
        let rawTemp = (Int16(data[0]) << 8) | Int16(data[1])
        return Float(rawTemp) / 340.0 + 36.53
    }


    /// Read x, y and z acceleration values in g (9.8m/s^2)
    /// within the selected range.
    /// - Returns: Accelerations on x, y, z-axes.
    public func readAcceleration() -> (x: Float, y: Float, z: Float) {
        let data = readRegister(.accelOut, count: 6)
        let rawX = (Int16(data[0]) << 8) | Int16(data[1])
        let rawY = (Int16(data[2]) << 8) | Int16(data[3])
        let rawZ = (Int16(data[4]) << 8) | Int16(data[5])

        let x = Float(rawX) / accelSensibility
        let y = Float(rawY) / accelSensibility
        let z = Float(rawZ) / accelSensibility

        return (x, y, z)
    }


    /// Read angular velocity on x, y and z axes. The values returned are in
    /// degree/sec.
    /// - Returns: Angular velocity on x, y, z-axes.
    public func readRotation() -> (x: Float, y: Float, z: Float) {
        let data = readRegister(.gyroOut, count: 6)
        let rawX = (Int16(data[0]) << 8) | Int16(data[1])
        let rawY = (Int16(data[2]) << 8) | Int16(data[3])
        let rawZ = (Int16(data[4]) << 8) | Int16(data[5])

        let x = Float(rawX) / gyroSensibility
        let y = Float(rawY) / gyroSensibility
        let z = Float(rawZ) / gyroSensibility

        return (x, y, z)
    }

    /// Get the bandwith of the digital low pass filter.
    /// - Returns: The bandwidth of the filter in `Bandwidth`.
    public func getFilterBandwidth() -> Bandwidth? {
        let value = readRegister(.config)
        if let value = value {
            return Bandwidth(rawValue: value & 0b0111)
        } else {
            return nil
        }
    }

    /// Set the digital low pass filter bandwidth.
    /// - Parameter bandwidth: A specified `Bandwidth`.
    public func setFilterBandwidth(_ bandwidth: Bandwidth) {
        let value = readRegister(.config)
        if let value = value {
            writeRegister(.config, (value & 0b1111_1000) | bandwidth.rawValue)
        }
    }


    /// Get the selected gyroscope range.
    /// - Returns: The measurement range of the gyroscope in `GyroRange`.
    public func getGyroRange() -> GyroRange? {
        let value = readRegister(.gyroConfig)
        if let value = value {
            return GyroRange(rawValue: value & 0b0001_1000)
        } else {
            return nil
        }
    }

    /// Set the gyroscope measurement range. It can be ±250, ±500, ±1000 or
    /// ±2000 degree per second. A smaller range will provide greater sensibility.
    /// - Parameter range: A specified `GyroRange`.
    public func setGyroRange(_ range: GyroRange) {
        gyroRange = range
        let value = readRegister(.gyroConfig)
        if let value = value {
            writeRegister(.gyroConfig, (value & 0b1110_0111) | range.rawValue)
        }
    }

    /// Get the selected accelerometer range.
    /// - Returns: The measurement range of the accelerometer in `AccelRange`.
    public func getAccelRange() -> AccelRange? {
        let value = readRegister(.accelConfig)
        if let value = value {
            return AccelRange(rawValue: value & 0b0001_1000)
        } else {
            return nil
        }
    }

    /// Set the accelerometer range. The supported ranges are ±2, ±4, ±8 and ±16g.
    /// A smaller range will provide greater sensibility.
    /// - Parameter range: A specified `AccelRange`.
    public func setAccelRange(_ range: AccelRange) {
        accelRange = range
        let value = readRegister(.accelConfig)
        if let value = value {
            writeRegister(.accelConfig, (value & 0b1110_0111) | range.rawValue)
        }
    }

    /// The bandwidth of the Digital low pass filter.
    public enum Bandwidth: UInt8 {
        case hz260 = 0
        case hz184 = 1
        case hz94 = 2
        case hz44 = 3
        case hz21 = 4
        case hz10 = 5
        case hz5 = 6
    }

    /// The measurement range of gyroscope.
    public enum GyroRange: UInt8 {
        /// The angular velocity ranges from -250°/sec to 250°/s.
        case dps250 = 0
        /// The angular velocity ranges from -500°/sec to 500°/s.
        case dps500 = 0b0000_1000
        /// The angular velocity ranges from -1000°/sec to 1000°/s.
        case dps1000 = 0b0001_0000
        /// The angular velocity ranges from -2000°/sec to 2000°/s.
        case dps2000 = 0b0001_1000
    }

    /// The measurement range of accelerometer.
    public enum AccelRange: UInt8 {
        /// The acceleration ranges from -2g to 2g.
        case g2 = 0
        /// The acceleration ranges from -4g to 4g.
        case g4 = 0b0000_1000
        /// The acceleration ranges from -8g to 8g.
        case g8 = 0b0001_0000
        /// The acceleration ranges from -16g to 16g.
        case g16 = 0b0001_1000
    }
}


extension MPU6050 {
    private enum Register: UInt8 {
        case powerManagement1 = 0x6B
        case powerManagement2 = 0x6C
        case whoAmI = 0x75
        case signalPathReset = 0x68
        case config = 0x1A
        case gyroConfig = 0x1B
        case accelConfig = 0x1C
        case accelOut = 0x3B
        case tempOut = 0x41
        case gyroOut = 0x43
        case sampleRateDivider = 0x19
    }

    private func reset() {
        // Reset all internal registers to their default values.
        writeRegister(.powerManagement1, 0b1000_0000)
        let resetBit = readRegister(.powerManagement1)! >> 7
        while resetBit != 0 {
            sleep(ms: 1)
        }
        sleep(ms: 100)

        // Reset the gyroscope, accelerometer, and temperature sensors.
        writeRegister(.signalPathReset, 0b01111)
        sleep(ms: 100)
    }

    private func writeRegister(_ reg: Register, _ value: UInt8) {
        i2c.write([reg.rawValue, value], to: address)
    }

    private func readRegister(_ reg: Register) -> UInt8? {
        i2c.write(reg.rawValue, to: address)
        let data = i2c.readByte(from: address)

        if let data = data {
            return data
        } else {
            return nil
        }
    }

    private func readRegister(_ register: Register, count: Int) -> [UInt8] {
        i2c.write(register.rawValue, to: address)
        let data = i2c.read(count: count, from: address)
        return data
    }
}
