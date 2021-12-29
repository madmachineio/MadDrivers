//=== HCSR04.swift --------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 11/12/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// The library for DS3231 real time clock.
///
/// You can read the time information including year, month, day, hour,
/// minute, second from it. It comes with a battery so the time will always
/// keep updated. Once powered off, the RTC needs a calibration. The RTC also
/// has two alarms and you can set them to alarm at a specified time.
final public class DS3231 {
    private let i2c: I2C
    private let address: UInt8

    private var daysInMonth: [UInt8] = [
        31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
    ]

    private var readBuffer = [UInt8](repeating: 0, count: 7)

    /// Initialize the RTC.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface the RTC connects to. The maximum
    ///   I2C speed is 400KHz.
    ///   - address: **OPTIONAL** The sensor's address. It has a default value 0x68.
    public init(_ i2c: I2C, _ address: UInt8 = 0x68) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": DS3231 only supports 100kbps and 400kbps I2C speed")
        }

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
        if lostPower() || update {
            let data = [
                binToBcd(time.second), binToBcd(time.minute),
                binToBcd(time.hour), binToBcd(time.dayOfWeek),
                binToBcd(time.day), binToBcd(time.month),
                binToBcd(UInt8(time.year - 2000))]

            try? writeRegister(Register.second, data)

            var byte: UInt8 = 0
            try? readRegister(Register.status, into: &byte)
            // Set OSF bit to 0, which means the RTC hasn't stopped
            // so far after the time is set.
            try? writeRegister(Register.status, byte & 0b0111_1111)
        }

    }

    /// Read current time.
    /// - Returns: The time info in a struct.
    public func readTime() -> Time {
        try? readRegister(.second, into: &readBuffer, count: 7)

        let year = UInt16(bcdToBin(readBuffer[6])) + 2000
        // Make sure the bit for century is 0.
        let month = bcdToBin(readBuffer[5] & 0b0111_1111)
        let day = bcdToBin(readBuffer[4])
        let dayOfWeek = bcdToBin(readBuffer[3])
        let hour = bcdToBin(readBuffer[2])
        let minute = bcdToBin(readBuffer[1])
        let second = bcdToBin(readBuffer[0])

        let time = Time(
            year: year, month: month, day: day, hour: hour,
            minute: minute, second: second, dayOfWeek: dayOfWeek)
        return time
    }

    /// Read current temperature.
    /// - Returns: Temperature in Celsius.
    public func readTemperature() -> Float {
        try? readRegister(.temperature, into: &readBuffer, count: 2)
        let temperature = Float(readBuffer[0]) + Float(readBuffer[1] >> 6) * 0.25
        return temperature
    }


    /// Set alarm1 at a specific time. The time can be decided by second,
    /// minute, hour, day or any combination of them.
    ///
    /// The alarm works only once. If you want it to happen continuously, you
    /// need to clear it manually when it is activated.
    ///
    /// Make sure the mode corresponds to the time you set. For example,
    /// you set the alarm to alert at 1m20s, like 1m20s, 1h1m20s... the mode
    /// should be `.minute`.
    ///
    /// - Parameters:
    ///   - day: The day from 1 to 31 in a month.
    ///   - dayOfWeek: The day from 1 to 7 in a week.
    ///   - hour: The hour from 0 to 23 in a day,
    ///   - minute: The minute from 0 to 59 in an hour.
    ///   - second: The second from 0 to 59 in a minute.
    ///   - mode: The alarm1 mode.
    public func setAlarm1(
        day: UInt8 = 0, dayOfWeek: UInt8 = 0, hour: UInt8 = 0,
        minute: UInt8 = 0, second: UInt8 = 0, mode: Alarm1Mode
    ) {
        clearAlarm(1)
        clearAlarm(2)
        disableAlarm(2)
        setSqwMode(SqwMode.off)

        // Bit7 of second.
        let A1M1 = (mode.rawValue & 0b0001) << 7
        // Bit7 of minute.
        let A1M2 = (mode.rawValue & 0b0010) << 6
        // Bit7 of hour.
        let A1M3 = (mode.rawValue & 0b0100) << 5
        // Bit7 of day.
        let A1M4 = (mode.rawValue & 0b1000) << 4
        // Bit6 of day to decide it is day of month or day of week.
        let DYDT = (mode.rawValue & 0b1_0000) << 2

        let second = binToBcd(second) | A1M1
        let minute = binToBcd(minute) | A1M2
        let hour = binToBcd(hour) | A1M3

        var day: UInt8 = 0
        if DYDT == 0 {
            day = binToBcd(day) | A1M4 | DYDT
        } else {
            day = binToBcd(dayOfWeek) | A1M4 | DYDT
        }

        let future = [second, minute, hour, day]
        try? writeRegister(Register.alarm1, future)

        var byte: UInt8 = 0
        try? readRegister(Register.control, into: &byte)

        if byte & 0b0100 != 0 {
            try? writeRegister(Register.control, byte | 0b01)
        }
    }

    /// Set alarm2 at a specific time. The time can be decided by minute,
    /// hour, day or any combination of them.
    ///
    /// The alarm works only once. If you want it to happen continuously, you
    /// need to clear it manually when it is activated.
    ///
    /// Make sure the mode corresponds to the time you set. For example,
    /// you set the alarm to alert at 2m, like 2m, 1h2m... the mode
    /// should be `.minute`.
    ///
    /// - Parameters:
    ///   - day: The day from 1 to 31 in a month.
    ///   - dayOfWeek: The day from 1 to 7 in a week.
    ///   - hour: The hour from 0 to 23 in a day.
    ///   - minute: The minute from 0 to 59 in an hour.
    ///   - mode: The alarm2 mode.
    public func setAlarm2(
        day: UInt8 = 0, dayOfWeek: UInt8 = 0, hour: UInt8 = 0,
        minute: UInt8 = 0, mode: Alarm2Mode
    ) {
        clearAlarm(1)
        clearAlarm(2)
        disableAlarm(1)
        setSqwMode(SqwMode.off)

        let A2M2 = (mode.rawValue & 0b0001) << 7
        let A2M3 = (mode.rawValue & 0b0010) << 6
        let A2M4 = (mode.rawValue & 0b0100) << 5
        let DYDT = (mode.rawValue & 0b1000) << 3

        let minute = binToBcd(minute) | A2M2
        let hour = binToBcd(hour) | A2M3
        var day: UInt8 = 0

        if DYDT == 0 {
            day = binToBcd(day) | A2M4 | DYDT
        } else {
            day = binToBcd(dayOfWeek) | A2M4 | DYDT
        }

        let future = [minute, hour, day]
        try? writeRegister(Register.alarm2, future)

        var byte: UInt8 = 0
        try? readRegister(Register.control, into: &byte)
        if byte & 0b0100 != 0 {
            try? writeRegister(Register.control, byte | 0b10)
        }
    }

    /// The alarm1 will activate after a specified time interval. The time
    /// can be specified as day, hour, minute, second or any combination of them.
    /// - Parameters:
    ///   - day: The days of time interval.
    ///   - hour: The hour of time interval.
    ///   - minute: The minutes of time interval.
    ///   - second: The seconds of time interval.
    ///   - mode: The alarm1 mode.
    public func setTimer1(
        day: UInt8 = 0, hour: UInt8 = 0, minute: UInt8 = 0,
        second: UInt8 = 0, mode: Alarm1Mode
    ) {
        let current = readTime()

        let futureSecond = (current.second + second) % 60
        let futureMinute = (current.minute + minute) % 60 +
        (current.second + second) / 60
        let futureHour = (current.hour + hour) % 24 +
        (current.minute + minute) / 60

        if current.year % 4 == 0 {
            daysInMonth[1] = 29
        }

        let totalDays: UInt8 = daysInMonth[Int(current.month - 1)]

        let futureDay = (current.day + day) % totalDays +
        (current.hour + hour) / 24

        setAlarm1(day: futureDay, hour: futureHour, minute: futureMinute,
                  second: futureSecond, mode: mode)
    }

    /// The alarm2 will activate after a specified time interval. The time
    /// can be specified as day, hour, minute or any combination of them.
    /// - Parameters:
    ///   - day: The days of time interval.
    ///   - hour: The hours of time interval.
    ///   - minute: The days of time interval.
    ///   - mode: The alarm2 mode.
    public func setTimer2(
        day: UInt8 = 0, hour: UInt8 = 0, minute: UInt8 = 0, mode: Alarm2Mode
    ) {
        let current = readTime()

        let futureMinute = (current.minute + minute) % 60
        let futureHour = (current.hour + hour) % 24 +
        (current.minute + minute) / 60

        if current.year % 4 == 0 {
            daysInMonth[1] = 29
        }

        let totalDays = daysInMonth[Int(current.month - 1)]

        let futureDay = (current.day + day) % totalDays +
        (current.hour + hour) / 24


        setAlarm2(day: futureDay, hour: futureHour,
                  minute: futureMinute, mode: mode)
    }

    /// Check if the specified alarm has been activated.
    /// If so, it returns true, if not, false.
    /// - Parameter alarm: The alarm 1 or 2.
    /// - Returns: A boolean value.
    public func alarmed(_ alarm: Int) -> Bool {
        var byte: UInt8 = 0
        try? readRegister(Register.status, into: &byte)
        let alarmFlag = byte & (~(0b1 << (alarm - 1)))
        return alarmFlag == 1
    }

    /// Clear the alarm status.
    /// - Parameter alarm: The alarm 1 or 2.
    public func clearAlarm(_ alarm: Int) {
        var byte: UInt8 = 0
        try? readRegister(Register.status, into: &byte)
        try? writeRegister(Register.status, byte & (~(0b1 << (alarm - 1))))

    }

    /// The mode of alarm1.
    public enum Alarm1Mode: UInt8 {
        /// Alarm per second.
        case perSecond = 0x0F
        /// Alarm when seconds match.
        case second = 0x0E
        /// Alarm when minutes and seconds match.
        case minute = 0x0C
        /// Alarm when hours, minutes and seconds match.
        case hour = 0x08
        /// Alarm when day of month, hours, minutes and seconds match.
        case dayOfMonth = 0x00
        /// Alarm when day of week, hours, minutes and seconds match.
        /// It doesn't work when you set timer1 and timer2.
        case dayOfWeek = 0x10
    }

    /// The mode of alarm2.
    public enum Alarm2Mode: UInt8 {
        /// Alarm once per minute (00 seconds of every minute).
        case perMinute = 0x7
        /// Alarm when minutes match.
        case minute = 0x6
        /// Alarm when hours and minutes match.
        case hour = 0x4
        /// Alarm when day of month, hours, minutes and seconds match.
        case dayOfMonth = 0x0
        /// Alarm when day of week, hours, minutes and seconds match.
        /// It doesn't work when you set timer1 and timer2.
        case dayOfWeek = 0x8
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

extension DS3231 {
    private enum Register: UInt8 {
        case second = 0x00
        case agingOffset = 0x10
        case alarm2 = 0x0B
        case alarm1 = 0x07
        case status = 0x0F
        case control = 0x0E
        case temperature = 0x11
    }

    private enum SqwMode: UInt8 {
      case off = 0x1C
      case hz1 = 0x00
      case kHz1 = 0x08
      case kHz4 = 0x10
      case kHz8 = 0x18
    }

    private func writeRegister(_ reg: Register, _ data: [UInt8]) throws {
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

    private func readRegister(_ reg: Register, into byte: inout UInt8) throws {
        var result = i2c.write(reg.rawValue, to: address)
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

    private func lostPower() -> Bool {
        var byte: UInt8 = 0
        try? readRegister(Register.status, into: &byte)
        let stopFlag = byte >> 7
        return stopFlag == 1
    }

    private func enable32K() {
        var byte: UInt8 = 0
        try? readRegister(Register.status, into: &byte)
        try? writeRegister(Register.status, byte | 0b1000)
    }

    private func disable32K() {
        var byte: UInt8 = 0
        try? readRegister(Register.status, into: &byte)
        try? writeRegister(Register.status, byte & 0b0111)
    }

    private func bcdToBin(_ value: UInt8) -> UInt8 {
        return value - 6 * (value >> 4)
    }

    private func binToBcd(_ value: UInt8) -> UInt8 {
        return value + 6 * (value / 10)
    }

    private func setSqwMode(_ mode: SqwMode) {
        var byte: UInt8 = 0
        try? readRegister(Register.control, into: &byte)
        try? writeRegister(Register.control, (byte & 0b0011) | mode.rawValue)
    }

    private func disableAlarm(_ alarm: Int) {
        var byte: UInt8 = 0
        try? readRegister(Register.control, into: &byte)
        try? writeRegister(Register.control, byte & (~(0b1 << (alarm - 1))))
    }
}
