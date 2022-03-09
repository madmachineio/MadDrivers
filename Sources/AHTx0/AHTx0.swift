//=== AHTx0.swift ---------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 03/09/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This library is for AHT10/AHT20 sensor to read temperature and relative
/// humidity. It supports I2C protocol.
///
/// The accuracy of the sensor is ±2% for relative humidity and ±0.3°C for
/// temperature. The sensor contains components sensitive to two factors.
/// During measurement, different temperature or humidity levels will change the
/// voltage in the circuit. Your board can read the voltage and calculate
/// the final results.
final public class AHTx0 {
    private let i2c: I2C
    private let address: UInt8
    private var readBuffer = [UInt8](repeating: 0, count: 6)

    /// Initialize the sensor using I2C communication.
    /// The sensor will be reset and calibrated after initialization.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects to.
    ///   - address: **OPTIONAL** The sensor's address, 0x38 by default.
    public init(_ i2c: I2C, address: UInt8 = 0x38) {
        self.i2c = i2c
        self.address = address

        sleep(ms: 20)
        reset()
        calibrate()
    }

    /// Get the temperature in Celcius.
    /// - Returns: A float representing the current temperature.
    public func readCelsius() -> Float {
        try? readSensorData(into: &readBuffer)
        let rawTemp = UInt32(readBuffer[3] & 0x0F) << 16 | UInt32(readBuffer[4]) << 8 | UInt32(readBuffer[5])
        return Float(rawTemp) * 200 / 0x100000 - 50
    }

    /// Read the current relative humidity.
    /// - Returns: A float between 0 and 100 representing the humidity.
    public func readHumidity() -> Float {
        try? readSensorData(into: &readBuffer)
        let rawHumi = UInt32(readBuffer[1]) << 12 | UInt32(readBuffer[2]) << 4 | UInt32(readBuffer[3]) >> 4
        return Float(rawHumi) * 100 / 0x100000
    }
}

extension AHTx0 {
    enum Command: UInt8 {
        case softReset = 0xBA
        case calibrate = 0xE1
        case triggerMeasurement = 0xAC
    }

    func writeValue(_ command: UInt8) throws {
        let result = i2c.write(command, to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func writeValues(_ data: [UInt8]) throws {
        let result = i2c.write(data, to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func readValue(into byte: inout UInt8) throws {
        let result = i2c.read(into: &byte, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func readValues(into buffer: inout [UInt8]) throws {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        let result = i2c.read(into: &buffer, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func reset() {
        try? writeValue(Command.softReset.rawValue)
        sleep(ms: 20)
    }

    func calibrate() {
        let data = [Command.calibrate.rawValue, 0x08, 0x00]
        try? writeValues(data)
        var status: UInt8

        repeat {
            status = readStatus()
            sleep(ms: 10)
        } while status & 0x80 != 0

        if status & 0x08 == 0 {
            fatalError(#function + ": calibration for AHTx0 failed")
        }
    }

    func readStatus() -> UInt8 {
        var byte: UInt8 = 0
        try? readValue(into: &byte)
        return byte
    }

    func readSensorData(into buffer: inout [UInt8]) throws {
        let data = [Command.triggerMeasurement.rawValue, 0x33, 0x00]
        try? writeValues(data)

        var status: UInt8

        repeat {
            status = readStatus()
            sleep(ms: 10)
        } while status & 0x80 != 0

        try? readValues(into: &buffer)
    }

}
