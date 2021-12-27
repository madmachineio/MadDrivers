//=== PCF8563.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 11/17/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// The library for PCF8563 real time clock.
///
/// You can read the time information including year, month, day, hour,
/// minute, second from it. It comes with a battery so the time will always
/// keep updated. Once powered off, the RTC needs a calibration.
final public class PCF8563 {
    private let i2c: I2C
    private let address: UInt8

    private var readBuffer = [UInt8](repeating: 0, count: 7)
    /// Initialize the RTC.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface the RTC connects to.
    ///   - address: **OPTIONAL** The sensor's address. It has a default value.
    public init(_ i2c: I2C, _ address: UInt8 = 0x51) {
        self.i2c = i2c
        self.address = address
    }

    /// Set current time to calibrate the RTC.
    ///
    /// If the RTC has stopped due to power off, it will be set to the
    /// specified time. If not, the time will not be reset by default.
    /// If you want to make it mandatory, you can set the parameter
    /// `update` to `true`.
    ///
    /// The time info includes the year, month, day, hour, minute, second,
    /// dayOfWeek. You may set Sunday or Monday as 0 for day of week.
    /// - Parameters:
    ///   - time: Current time from year to second.
    ///   - update: Whether to update the time.
    public func setTime(_ time: Time, update: Bool = false) {
        if lostPower() || update {
            let data = [
                binToBcd(time.second), binToBcd(time.minute),
                binToBcd(time.hour), binToBcd(time.day),
                binToBcd(time.dayOfWeek), binToBcd(time.month),
                binToBcd(UInt8(time.year - 2000))]

            try? writeData(Register.vlSecond, data)
        }
    }

    /// Read current time. The time info is stored in a struct including the
    /// year, month, day, hour, minute, second, dayOfWeek. 
    /// - Returns: A Time struct if the communication is stable. Or it will be nil.
    public func readCurrent() -> Time {
        try? readRegister(.vlSecond, into: &readBuffer, count: 7)

        let year = UInt16(bcdToBin(readBuffer[6])) + 2000
        let month = bcdToBin(readBuffer[5] & 0b0001_1111)
        let dayOfWeek = bcdToBin(readBuffer[4] & 0b0000_0111)
        let day = bcdToBin(readBuffer[3] & 0b0011_1111)
        let hour = bcdToBin(readBuffer[2] & 0b0011_1111)
        let minute = bcdToBin(readBuffer[1] & 0b0111_1111)
        let second = bcdToBin(readBuffer[0] & 0b0111_1111)

        let time = Time(
            year: year, month: month, day: day, hour: hour,
            minute: minute, second: second, dayOfWeek: dayOfWeek)
        return time
    }

    /// Check if the clock is running. If so, it returns true and the time is
    /// accurate. If it stops, it returns false.
    /// - Returns: Boolean value representing the status of the RTC.
    public func isRunning() -> Bool {
        var byte: UInt8 = 0
        try? readRegister(Register.control1, into: &byte)
        let stopBit = byte >> 5 & 0b1
        return stopBit != 1
    }

    /// Make the clock start to work so the time will keep updated.
    public func start() {
        var byte: UInt8 = 0
        try? readRegister(Register.control1, into: &byte)

        if byte >> 5 & 0b1 == 1 {
            try? writeRegister(Register.control1, byte & (~(1 << 5)))
        }
    }

    /// Stop the internal clock, and the time you read from the RTC will not
    /// be accurate anymore.
    public func stop() {
        var byte: UInt8 = 0
        try? readRegister(Register.control1, into: &byte)

        if byte >> 5 & 0b1 == 0 {
            try? writeRegister(Register.control1, byte | (1 << 5))
        }
    }

    /// Store the time info.
    ///
    /// The dayOfWeek is from 0 to 6. You can decide that Sunday or Monday is 0
    /// when adjusting the current time.
    public struct Time {
        public let year: UInt16
        public let month: UInt8
        public let day: UInt8
        public let hour: UInt8
        public let minute: UInt8
        public let second: UInt8
        public let dayOfWeek: UInt8

        public init(
            year: UInt16, month: UInt8, day: UInt8,
            hour: UInt8, minute: UInt8, second: UInt8,
            dayOfWeek: UInt8
        ) {
            self.year = year
            self.month = month
            self.day = day
            self.hour = hour
            self.minute = minute
            self.second = second
            self.dayOfWeek = dayOfWeek
        }
    }
}

extension PCF8563 {

    private enum Register: UInt8 {
        case control1 = 0x00
        case control2 = 0x01
        case vlSecond = 0x02
        case clkout = 0x0D
        case timerControl = 0x0E
        case timer = 0x0F
    }

    private func bcdToBin(_ value: UInt8) -> UInt8 {
        return value - 6 * (value >> 4)
    }

    private func binToBcd(_ value: UInt8) -> UInt8 {
        return value + 6 * (value / 10)
    }

    private func lostPower() -> Bool {
        var byte: UInt8 = 0
        try? readRegister(Register.vlSecond, into: &byte)
        let vl = byte >> 7
        return vl == 1
    }

    private func writeData(_ reg: Register, _ data: [UInt8]) throws {
        var data = data
        data.insert(reg.rawValue, at: 0)
        let result = i2c.write(data, to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func writeRegister(_ reg: Register, _ value: UInt8) throws {
        let result = i2c.write([reg.rawValue, value], to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func readRegister(
        _ register: Register, into byte: inout UInt8
    ) throws {
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
    ) throws {
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
}
