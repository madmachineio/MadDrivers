//=== PCF8563.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 11/17/2021
// Updated: 11/17/2021
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
    /// - Parameters:
    ///   - time: Current time from year to second.
    ///   - update: Whether to update the time.
    public func setTime(_ time: Time, update: Bool = false) {
        let powerStatus = lostPower()
        if let powerStatus = powerStatus {
            if powerStatus || update {
                let data = [
                    binToBcd(time.second), binToBcd(time.minute),
                    binToBcd(time.hour), binToBcd(time.day),
                    binToBcd(time.dayOfWeek), binToBcd(time.month),
                    binToBcd(UInt8(time.year - 2000))]

                writeData(Register.vlSecond, data)
            }
        }
    }

    /// Read current time. The time info includes the year, month, day, hour,
    /// minute, second, dayOfWeek. The dayOfWeek value (0-6) depends on the time
    /// you set. You may set Sunday or Monday as 0.
    /// - Returns: The time info in a struct if the communication is stable.
    public func readCurrent() -> Time? {
        i2c.write(Register.vlSecond.rawValue, to: address)
        let data = i2c.read(count: 7, from: address)

        if data.count != 7 {
            print("readCurrent error")
            return nil
        } else {
            let year = UInt16(bcdToBin(data[6])) + 2000
            let month = bcdToBin(data[5] & 0b0001_1111)
            let dayOfWeek = bcdToBin(data[4] & 0b0000_0111)
            let day = bcdToBin(data[3] & 0b0011_1111)
            let hour = bcdToBin(data[2] & 0b0011_1111)
            let minute = bcdToBin(data[1] & 0b0111_1111)
            let second = bcdToBin(data[0] & 0b0111_1111)

            let time = Time(
                year: year, month: month, day: day, hour: hour,
                minute: minute, second: second, dayOfWeek: dayOfWeek)
            return time
        }
    }

    /// Check if the clock is running. If so, it returns true and the time is
    /// accurate. If it stops, it returns false.
    /// - Returns: Boolean value representing the status of the RTC.
    public func isRunning() -> Bool? {
        let data = readRegister(Register.vlSecond)
        var stopBit: UInt8 = 2

        if let data = data {
            stopBit = data >> 5 & 0b1
        } else {
            print("read power status error")
            return nil
        }

        if stopBit == 1 {
            return false
        } else {
            return true
        }
    }

    /// Make the clock start to work so the time will keep being updated.
    public func start() {
        let data = readRegister(Register.control1)

        if let data = data {
            if data >> 5 & 0b1 == 1 {
                writeRegister(Register.control1, data & (~(1 << 5)))
            }
        } else {
            print("read stop bit error")
        }
    }

    /// Stop the internal clock, so the time will not be updated any longer.
    public func stop() {
        let data = readRegister(Register.control1)

        if let data = data {
            if data >> 5 & 0b1 == 0 {
                writeRegister(Register.control1, data | (1 << 5))
            }
        } else {
            print("read stop bit error")
        }
    }

    /// Store the time info.
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

    private func bcdToBin(_ value: UInt8) -> UInt8 {
        return value - 6 * (value >> 4)
    }

    private func binToBcd(_ value: UInt8) -> UInt8 {
        return value + 6 * (value / 10)
    }

    private func lostPower() -> Bool? {
        let data = readRegister(Register.vlSecond)
        var vl: UInt8 = 2

        if let data = data {
            vl = data >> 7
        } else {
            print("read power status error")
            return nil
        }

        if vl == 1 {
            return true
        } else {
            return false
        }
    }

    private enum Register: UInt8 {
        case control1 = 0x00
        case control2 = 0x01
        case vlSecond = 0x02
        case clkout = 0x0D
        case timerControl = 0x0E
        case timer = 0x0F
    }

    private func writeData(_ reg: Register, _ data: [UInt8]) {
        var data = data
        data.insert(reg.rawValue, at: 0)
        i2c.write(data, to: address)
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
            print("readByte error")
            return nil
        }
    }
}
