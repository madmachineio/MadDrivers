//=== MAG3110.swift --------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 01/13/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO
// import RealModule

/// This is the library for MAG3110 3-axis magnetometer.
///
/// The MAG3110 allows you to measure the sourrounding magnetic field on
/// x, y, z axis. You can even use it to make a digital compass. It outputs values
/// from -30000 to 30000 and provides full-scale range of ±1000 microteslas.
final public class MAG3110 {
    private let i2c: I2C
    private let address: UInt8
    private var readBuffer = [UInt8](repeating: 0, count: 6)

    private var xScale: Float = 0
    private var yScale: Float = 0

    /// Initialize the sensor using I2C communication.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   The maximum I2C speed is 400KHz.
    ///   - address: **OPTIONAL** The device address of the sensor. 0x0E by default.
    public init(_ i2c: I2C, address: UInt8 = 0x0E) {
        self.i2c = i2c
        self.address = address

        guard (i2c.getSpeed() == .standard) || (i2c.getSpeed() == .fast) else {
            print(#function + ": MAG3110 only supports 100kHz (standard) and 400kHz (fast) I2C speed")
            fatalError()
        }

        guard getDeviceID() == 0xC4 else {
            print(#function + ": Fail to find MAG3110 at address \(address)")
            fatalError()
        }

        reset()
    }

    /// Read raw values of the magnetic field strength.
    /// - Returns: x, y, z axis 16-bit raw values.
    public func readRawValues() -> (x: Int16, y: Int16, z: Int16) {
        guard isDataAvailable() == true else { return (0, 0, 0) }
        try? readRegister(.outXMSB, into: &readBuffer, count: 6)
        let x = (Int16(readBuffer[0]) << 8) | Int16(readBuffer[1])
        let y = (Int16(readBuffer[2]) << 8) | Int16(readBuffer[3])
        let z = (Int16(readBuffer[4]) << 8) | Int16(readBuffer[5])
        return (x, y, z)
    }

    /// Read the magnetic field strength and return the data in µTeslas.
    /// - Returns: magnetic fields on x, y, z axis in µTeslas.
    public func readMicroTeslas() -> (x: Float, y: Float, z: Float) {
        let values = readRawValues()
        let x = Float(values.x) * 0.1
        let y = Float(values.y) * 0.1
        let z = Float(values.z) * 0.1
        return (x, y, z)
    }

    /// Get magnetic north headings. Make sure to calibrate the sensor first,
    /// or the reading will be 0. You could infer the heading according to the
    /// readings: north is at 0°, east is at 90°, south is at 180°, and west
    /// is at 270°
    /// - Returns: The angle in a clockwise direction from North.
    public func readHeading() -> Float {
        let rawValues = readRawValues()
        let x = Float(rawValues.x)
        let y = Float(rawValues.y)
        var angle = Float.atan2(y: y * yScale, x: x * xScale) * 180 / Float.pi
        if angle < 0 {
            angle += 360
        }
        return angle
    }

    /// Set data rate and sampling ratio. More detailed info are in the
    /// [datasheet](https://www.nxp.com/docs/en/data-sheet/MAG3110.pdf).
    /// - Parameters:
    ///   - datarate: A number from 0 to 7.
    ///   - sampling: An oversampling rate in enum `Oversampling`
    public func setMeasurement(datarate: UInt8, sampling: Oversampling) {
        let mode = getMode()
        if mode == .active {
            setMode(.standby)
        }
        sleep(ms: 100)

        var byte: UInt8 = 0
        try? readRegister(.ctrlReg1, into: &byte)
        byte = (byte & 0x07) | (datarate << 5) | (sampling.rawValue << 3)
        try? writeRegister(.ctrlReg1, byte)
        sleep(ms: 100)

        if mode == .active {
            setMode(.active)
        }
    }

    /// Calibrate the sensor to offset the surrounding static magnetic fields.
    /// The preset calibration duration is 5s. You need to rotate the sensor
    /// 360 degrees while keeping it level.
    public func calibrate() {
        var xmin: Int16 = 32767
        var xmax: Int16 = -32768
        var ymin: Int16 = 32767
        var ymax: Int16 = -32768

        var lastTime: Int64 = 0

        /// Ensure the raw data is not corrected by the specified offset.
        try? writeRegister(.ctrlReg2, 0b1010_0000)

        /// Set to the highest data rate and oversampling for continuous reading.
        setMeasurement(datarate: 0, sampling: .x16)
        setMode(.active)

        var calibrated = false

        while !calibrated {
            /// Use the raw values for calibration.
            let rawValues = readRawValues()
            var changed = false

            if rawValues.x < xmin {
                xmin = rawValues.x
                changed = true
            }

            if rawValues.x > xmax {
                xmax = rawValues.x
                changed = true
            }

            if rawValues.y < ymin {
                ymin = rawValues.y
                changed = true
            }

            if rawValues.y > ymax {
                ymax = rawValues.y
                changed = true
            }

            if changed {
                lastTime = getSystemUptimeInMilliseconds()
            }

            if getSystemUptimeInMilliseconds() - lastTime > 5000 {
                let xOffset = (xmin + xmax) / 2
                let yOffset = (ymin + ymax) / 2

                xScale = 1.0 / Float(xmax - xmin)
                yScale = 1.0 / Float(ymax - ymin)

                setOffset(x: xOffset, y: yOffset, z: 0)
                /// Go back to normal mode so the following data will be
                /// corrected by the offset.
                try? writeRegister(.ctrlReg2, 0b1000_0000)
                calibrated = true
            }
        }
    }

    /// The sampling ratio for the measurement.
    public enum Oversampling: UInt8 {
        case x16 = 0
        case x32 = 1
        case x64 = 2
        case x128 = 3
    }
}

extension MAG3110 {
    private enum Register: UInt8 {
        case status = 0x00
        case outXMSB = 0x01
        case whoAmI = 0x07
        case sysMod = 0x08
        case offXMSB = 0x09
        case ctrlReg1 = 0x10
        case ctrlReg2 = 0x11
    }

    enum Mode: UInt8 {
        case standby = 0
        case active = 1
    }

    private func readRegister(
        _ register: Register, into byte: inout UInt8
    ) throws(Errno) {
        var result = i2c.write(register.rawValue, to: address)
        if case .failure(let err) = result {
            throw err
        }

        result = i2c.read(into: &byte, from: address)
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

        var result = i2c.write(register.rawValue, to: address)
        if case .failure(let err) = result {
            throw err
        }

        result = i2c.read(into: &buffer, count: count, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func writeRegister(_ register: Register, _ value: UInt8) throws(Errno) {
        let result = i2c.write([register.rawValue, value], to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func writeRegister(_ register: Register, _ data: [UInt8]) throws(Errno) {
        var data = data
        data.insert(register.rawValue, at: 0)
        let result = i2c.write(data, to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func getDeviceID() -> UInt8 {
        var byte: UInt8 = 0
        try? readRegister(.whoAmI, into: &byte)
        return byte
    }

    func setMode(_ mode: Mode) {
        var byte: UInt8 = 0
        try? readRegister(.ctrlReg1, into: &byte)
        try? writeRegister(.ctrlReg1, byte & 0b1111_1100 | mode.rawValue)
    }

    func getMode() -> Mode {
        var byte: UInt8 = 0
        try? readRegister(.sysMod, into: &byte)
        if byte >> 6 == 0 {
            return .standby
        } else {
            return .active
        }
    }

    func setOffset(x: Int16, y: Int16, z: Int16) {
        let xOffset = UInt16(bitPattern: x) << 1
        let yOffset = UInt16(bitPattern: y) << 1
        let zOffset = UInt16(bitPattern: z) << 1

        let data = [UInt8(xOffset >> 8), UInt8(xOffset & 0xFF),
                    UInt8(yOffset >> 8), UInt8(yOffset & 0xFF),
                    UInt8(zOffset >> 8), UInt8(zOffset & 0xFF)]
        try? writeRegister(.offXMSB, data)
    }

    func reset() {
        setMode(.standby)
        try? writeRegister(.ctrlReg1, 0)
        try? writeRegister(.ctrlReg2, 0x80)
        setOffset(x: 0, y: 0, z: 0)
        setMode(.active)
    }

    func isDataAvailable() -> Bool {
        var byte: UInt8 = 0
        try? readRegister(.status, into: &byte)
        return byte & 0x80 != 0
    }
}

@_extern(c, "atan2f")
func atan2f(_: Float, _: Float) -> Float

private extension Float {
  @_transparent
  static func atan2(y: Float, x: Float) -> Float {
    atan2f(y, x)
  }
}