//=== BMI160.swift --------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 07/09/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for BMI160 accelerometer and gyroscope. It supports I2C
/// and SPI communication.
///
/// The BMI160 contains 16-bit gyroscope and accelerometer. The accelerometer
/// can measure triaxial acceleration and return the values in g (9.8m/s^2).
/// The gyroscope can measure triaxial angular velocity. The values are in degree
/// per second (dps).
///
/// It provides selectable measurement range for acceleration (±2g, ±4g, ±8g, ±16g)
/// and rotation (±125, ±250, ±500, ±1000, ±2000dps). You can adjust it according
/// to the movement.
final public class BMI160 {
    private let i2c: I2C?
    private let address: UInt8

    private let spi: SPI?
    private let csPin: DigitalOut?

    private var readBuffer = [UInt8](repeating: 0, count: 7)

    private var accelRange: AccelRange
    private var accelRangeValue: Float {
        switch accelRange {
        case .g2:
            return 2
        case .g4:
            return 4
        case .g8:
            return 8
        case .g16:
            return 16
        }
    }

    private var gyroRange: GyroRange
    private var gyroRangeValue: Float {
        switch gyroRange {
        case .dps2000:
            return 2000
        case .dps1000:
            return 1000
        case .dps500:
            return 500
        case .dps250:
            return 250
        case .dps125:
            return 125
        }
    }

    /// Initialize the sensor using I2C communication.
    ///
    /// The default acceleration range is ±2g and rotation is ±250 degree per
    /// second (dps).
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   - address: **OPTIONAL** The device address of the sensor, 0x68 by default.
    ///   It's 0x68 if SDO is connected to GND and 0x69 if connected to power.
    public init(_ i2c: I2C, address: UInt8 = 0x68) {
        self.i2c = i2c
        self.address = address

        self.spi = nil
        self.csPin = nil

        accelRange = .g2
        gyroRange = .dps250

        guard getChipID() == 0xD1 else {
            print(#function + ": Fail to find BMI160 at address \(address)")
            fatalError()
        }

        reset()
        powerUp()

        setGyroRange(gyroRange)
        setAccelRange(accelRange)

        try? writeRegister(.INT_MAP0, 0xFF)
        try? writeRegister(.INT_MAP1, 0xF0)
        try? writeRegister(.INT_MAP2, 0x00)
    }

    /// Initialize the sensor using SPI communication.
    ///
    /// The default acceleration range is ±2g and rotation is ±250 degree per
    /// second (dps).
    /// - Parameters:
    ///   - spi: **REQUIRED** The SPI interface that the sensor connects.
    ///   The maximum SPI clock speed is **10MHz**. The **CPOL and CPHA** should
    ///   be **both true** or **both false**.
    ///   - csPin: **OPTIONAL** The cs pin for the spi. If you set the cs when
    ///   initializing the spi interface, `csPin` should be nil. If not, you
    ///   need to set a digital output pin as the cs pin. And the mode of the pin
    ///   should be **pushPull**.
    public init(_ spi: SPI, csPin: DigitalOut? = nil) {
        self.spi = spi
        self.csPin = csPin
        self.i2c = nil
        self.address = 0

        csPin?.high()

        guard (spi.cs == false && csPin != nil && csPin!.getMode() == .pushPull)
                || (spi.cs == true && csPin == nil) else {
                    print(#function + ": csPin isn't correctly configured")
                    fatalError()
        }

        guard spi.getMode() == (true, true, .MSB) ||
                spi.getMode() == (false, false, .MSB) else {
            print(#function + ": SPI mode doesn't match for BMI160. CPOL and CPHA should be both true or both false and bitOrder should be .MSB")
            fatalError()
        }

        guard spi.getSpeed() <= 10_000_000 else {
            print(#function + ": BMI160 cannot support spi speed faster than 10MHz")
            fatalError()
        }

        accelRange = .g2
        gyroRange = .dps250

        spiDummyRead()
        reset()
        spiDummyRead()

        guard getChipID() == 0xD1 else {
            print(#function + ": Fail to find BMI160 with default ID via SPI")
            fatalError()
        }

        powerUp()

        setGyroRange(gyroRange)
        setAccelRange(accelRange)

        try? writeRegister(.INT_MAP0, 0xFF)
        try? writeRegister(.INT_MAP1, 0xF0)
        try? writeRegister(.INT_MAP2, 0x00)
    }

    /// Read raw value of the acceleration in x, y, z-axis.
    /// - Returns: Raw values of the acceleration in three axis.
    public func readRawAcceleration() -> (x: Int16, y: Int16, z: Int16) {
        try? readRegister(.ACCEL_X_L, into: &readBuffer, count: 6)
        let x = Int16(readBuffer[0]) | (Int16(readBuffer[1]) << 8)
        let y = Int16(readBuffer[2]) | (Int16(readBuffer[3]) << 8)
        let z = Int16(readBuffer[4]) | (Int16(readBuffer[5]) << 8)
        return (x, y, z)
    }

    /// Read the acceleration in x, y, z-axis and calculate the values in g (9.8m/s^2).
    /// - Returns: Accelerations in three axis measured in g.
    public func readAcceleration() -> (x: Float, y: Float, z: Float) {
        let raw = readRawAcceleration()
        return (convertRaw(raw.x, range: accelRangeValue),
                convertRaw(raw.y, range: accelRangeValue),
                convertRaw(raw.z, range: accelRangeValue))
    }

    /// Read raw value of the rotation in x, y, z-axis.
    /// - Returns: Raw values of the rotation in three axis.
    public func readRawRotation() -> (x: Int16, y: Int16, z: Int16) {
        try? readRegister(.GYRO_X_L, into: &readBuffer, count: 6)
        let x = Int16(readBuffer[0]) | (Int16(readBuffer[1]) << 8)
        let y = Int16(readBuffer[2]) | (Int16(readBuffer[3]) << 8)
        let z = Int16(readBuffer[4]) | (Int16(readBuffer[5]) << 8)
        return (x, y, z)
    }

    /// Read the rotation in x, y, z-axis and calculate the value in dps (degree/second).
    /// - Returns: Rotation in dps in three axis.
    public func readRotation() -> (x: Float, y: Float, z: Float) {
        let raw = readRawRotation()
        return (convertRaw(raw.x, range: gyroRangeValue),
                convertRaw(raw.y, range: gyroRangeValue),
                convertRaw(raw.z, range: gyroRangeValue))
    }

    /// Set a specified rotation range for the gyroscope.
    /// - Parameter range: A range in ``GyroRange``.
    public func setGyroRange(_ range: GyroRange) {
        try? writeRegister(.GYR_RANGE, range.rawValue)
        gyroRange = range
    }

    /// Get the current gyroscope measurement range.
    /// - Returns: A range in ``GyroRange``.
    public func getGyroRange() -> GyroRange {
        return gyroRange
    }

    /// Set a specified acceleration range for the measurement.
    /// - Parameter range: A range in ``AccelRange``.
    public func setAccelRange(_ range: AccelRange) {
        try? writeRegister(.ACC_RANGE, range.rawValue)
        accelRange = range
    }

    /// Get the measurement range of the acceleration.
    /// - Returns: A range in ``AccelRange``.
    public func getAccelRange() -> AccelRange {
        return accelRange
    }

    /// The rotation range that the sensor can measure, ±250dps by default.
    public enum GyroRange: UInt8 {
        /// ±2000 degrees/second
        case dps2000 = 0
        /// ±1000 degrees/second
        case dps1000 = 1
        /// ±500 degrees/second
        case dps500 = 2
        /// ±250 degrees/second
        case dps250 = 3
        /// ±125 degrees/second
        case dps125 = 4
    }

    /// The acceleration range that the sensor can measure, ±2g by default.
    public enum AccelRange: UInt8 {
        /// ±2g
        case g2  = 0x03
        /// ±4g
        case g4  = 0x05
        /// ±8g
        case g8  = 0x08
        /// ±16g
        case g16 = 0x0C
    }
}


extension BMI160 {
    enum Register: UInt8 {
        case CMD = 0x7E
        case CHIPID = 0x00
        case PMU_STATUS = 0x03
        case GYR_RANGE = 0x43
        case ACC_RANGE = 0x41
        case INT_MAP0 = 0x55
        case INT_MAP1 = 0x56
        case INT_MAP2 = 0x57
        case ACCEL_X_L = 0x12
        case GYRO_X_L = 0x0C
        case ACCEL_CONF = 0x40
        case GYRO_CONF = 0x42
        case SPI = 0x7F
    }

    enum Command: UInt8 {
        case softReset = 0xB6
        case accelNormalMode = 0x11
        case gyroNormalMode = 0x15

    }

    private func readRegister(
        _ register: Register, into byte: inout UInt8
    ) throws(Errno) {
        var result: Result<(), Errno>

        if i2c != nil {
            result = i2c!.write(register.rawValue, to: address)
            if case .failure(let err) = result {
                throw err
            }

            result = i2c!.read(into: &byte, from: address)
        } else {
            var tempBuffer: [UInt8] = [0, 0]
            csPin?.low()
            result = spi!.transceive(register.rawValue | 0x80, into: &tempBuffer)
            csPin?.high()
            byte = tempBuffer[1]
        }

        if case .failure(let err) = result {
            throw err
        }
    }

    private func readRegister(
        _ register: Register, into buffer: inout [UInt8], count: Int
    ) throws(Errno) {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }
        var result: Result<(), Errno>
        if i2c != nil {
            result = i2c!.write(register.rawValue, to: address)
            if case .failure(let err) = result {
                throw err
            }

            result = i2c!.read(into: &buffer, count: count, from: address)

        } else {
            csPin?.low()
            result = spi!.transceive(register.rawValue | 0x80, into: &buffer, readCount: count + 1)
            csPin?.high()
            
            for i in 0..<count {
                buffer[i] = buffer[i + 1]
            }
        }

        if case .failure(let err) = result {
            throw err
        }

    }

    private func writeRegister(_ register: Register, _ value: UInt8) throws(Errno) {
        var result: Result<(), Errno>

        if i2c != nil {
            result = i2c!.write([register.rawValue, value], to: address)
        } else {
            csPin?.low()
            result = spi!.write([register.rawValue, value])
            csPin?.high()
        }

        if case .failure(let err) = result {
            throw err
        }

    }

    private func writeCommand(_ command: Command) throws(Errno) {
        try writeRegister(.CMD, command.rawValue)
    }

    /// Set accelerometer and gyroscope to normal mode.
    func powerUp() {
        try? writeCommand(.accelNormalMode)
        sleep(ms: 1)

        var status: UInt8 = 0
        try? readRegister(.PMU_STATUS, into: &status)
        while (status & 0b0011_0000) >> 4 != 1 {
            sleep(ms: 1)
            try? readRegister(.PMU_STATUS, into: &status)
        }

        try? writeCommand(.gyroNormalMode)
        sleep(ms: 1)

        try? readRegister(.PMU_STATUS, into: &status)
        while (status & 0b1100) >> 2 != 1 {
            sleep(ms: 1)
            try? readRegister(.PMU_STATUS, into: &status)
        }
    }

    func reset() {
        try? writeCommand(.softReset)
        sleep(ms: 1)
    }

    func getChipID() -> UInt8 {
        var id: UInt8 = 0
        try? readRegister(.CHIPID, into: &id)
        return id
    }

    /// The raw is -32768 to 32767. It will be matched to acceleration/rotation within its range.
    /// If the accelerometer range is ±2g, the raw value -32768 matches -2g, 32767 matches 2g.
    func convertRaw(_ raw: Int16, range: Float) -> Float {
        return range * 2 / 65535 * (Float(raw) + 32768) - range
    }

    /// Dummy read of 0x7F register to enable SPI Interface
    func spiDummyRead() {
        var byte: UInt8 = 0
        try? readRegister(.SPI, into: &byte)
        sleep(ms: 1)
    }
}
