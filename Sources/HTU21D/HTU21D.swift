//=== BMP280.swift --------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 04/17/2023
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for HTU21D temperature and humidity sensor.
final public class HTU21D {
    private let i2c: I2C
    private let address: UInt8

    /// Initialize the sensor using I2C communication.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface the sensor connects to.
    ///   The maximum I2C speed is 400KHz.
    ///   - address: **OPTIONAL** The sensor's address. It has a default value 0x40.
    public init(_ i2c: I2C, address: UInt8 = 0x40) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            print(#function + ": HTU21D only supports 100kHz (standard) and 400kHz (fast) I2C speed")
            fatalError()
        }

        self.i2c = i2c
        self.address = address
        try? reset()
    }

    /// Read the relative humidity.
    /// - Returns: A float from 0 to 100 representing the humidity.
    public func readHumidity() throws(HTU21DError) -> Float {
        let value = try readRawValue(.humidity)
        return Float(value) * 125.0 / 65536.0 - 6.0
    }

    /// Read the temperature in Celcius.
    /// - Returns: A float representing the current temperature.
    public func readTemperature() throws(HTU21DError) -> Float {
        let value = try readRawValue(.temperature)
        return Float(value) * 175.72 / 65536.0 - 46.85
    }

    /// Set the resolution for temperature and humidity measurement.
    /// - Parameter resolution: A measurement resolution for temperature and humidity.
    public func setResolution(_ resolution: Resolution) throws(HTU21DError) {
        var byte: UInt8 = 0
        try readRegister(.readUserRegister, into: &byte)

        let value = (byte & 0b0111_1110) | resolution.rawValue
        try writeRegister(value, to: .writeUserRegister)
    }

    /// Get the resolution for temperature and humidity measurement.
    /// - Returns: The current measurement resolution.
    public func getResolution() throws(HTU21DError) -> Resolution {
        var byte: UInt8 = 0
        try readRegister(.readUserRegister, into: &byte)
        return Resolution(rawValue: byte & 0b1000_0001)!
    }

    /// The resolutions for temperature and humidity measurement.
    public enum Resolution: UInt8 {
        /// RH: 12bit, T: 14bit. The default resolution.
        case resolution0 = 0b0
        /// RH: 8bit, T: 12bit.
        case resolution1 = 0b1
        /// RH: 10bit, T: 13bit.
        case resolution2 = 0b1000_0000
        /// RH: 11bit, T: 11bit.
        case resolution3 = 0b1000_0001
    }
}

extension HTU21D {
    enum Command: UInt8 {
        case temperature = 0xF3
        case humidity = 0xF5
        case reset = 0xFE
        case writeUserRegister = 0xE6
        case readUserRegister = 0xE7
    }

    func readRegister(_ register: Command, into byte: inout UInt8) throws(HTU21DError) {
        let result = i2c.writeRead(register.rawValue, into: &byte, address: address)
        if case .failure(_) = result {
            throw HTU21DError.readError
        }
    }

    func writeRegister(_ value: UInt8, to register: Command) throws(HTU21DError) {
        let result = i2c.write([register.rawValue, value], to: address)
        if case .failure(_) = result {
            throw HTU21DError.writeError
        }
    }

    func writeValue(_ command: Command) throws(HTU21DError) {
        let result = i2c.write([command.rawValue], to: address)
        if case .failure(_) = result {
            throw HTU21DError.writeError
        }
    }

    /// Reboot the sensor switching the power off and on again
    func reset() throws(HTU21DError) {
        try writeValue(.reset)
        /// The soft reset takes less than 15ms.
        sleep(ms: 15)
    }

    private func readValue(into buffer: inout [UInt8]) throws(HTU21DError) {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }
        let result = i2c.read(into: &buffer, from: address)
        if case .failure(_) = result {
            throw HTU21DError.readError
        }
    }

    func readRawValue(_ command: Command) throws(HTU21DError) -> UInt16 {
        try writeValue(command)
        if command == .humidity {
            /// Max humidity maeasuring time.
            sleep(ms: 16)
        } else if command == .temperature {
            /// Max temperature maeasuring time.
            sleep(ms: 50)
        }

        var buffer = [UInt8](repeating: 0, count: 3)
        try? readValue(into: &buffer)

        if calculateCRC([buffer[0], buffer[1]]) == buffer[2] {
            return (UInt16(buffer[0]) << 8 | UInt16(buffer[1])) & 0xFFFC
        } else {
            throw HTU21DError.crcError
        }
    }

    func calculateCRC(_ data: [UInt8]) -> UInt8 {
        var crc: UInt16 = 0

        for byte in data {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                if crc & 0x80 != 0 {
                    crc <<= 1
                    crc ^= 0x131
                } else {
                    crc <<= 1
                }
            }
        }
        return UInt8(crc)
    }

}


public enum HTU21DError: Error {
    case readError
    case writeError
    case crcError
}
