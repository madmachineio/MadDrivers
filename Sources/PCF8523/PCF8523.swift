//=== PCF8523.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 11/20/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

final public class PCF8523 {
    private let i2c: I2C
    private let address: UInt8

    private var readBuffer = [UInt8](repeating: 0, count: 7)

    /// Initialize the RTC.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface the RTC connects to.
    ///   - address: **OPTIONAL** The sensor's address. It has a default value.
    public init(_ i2c: I2C, _ address: UInt8 = 0x68) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": PCF8523 only supports 100kbps and 400kbps I2C speed")
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
    ///
    /// The time info includes the year, month, day, hour, minute, second,
    /// dayOfWeek. You may set Sunday or Monday as 0 for day of week.
    /// - Parameters:
    ///   - time: Current time from year to second.
    ///   - update: Whether to update the time. If the RTC has lost power,
    ///     the time will be reset no matter its value.
    public func setTime(_ time: Time, update: Bool = false) {

        if lostPower() || update {
            let data = [
                binToBcd(time.second), binToBcd(time.minute),
                binToBcd(time.hour), binToBcd(time.day),
                binToBcd(time.dayOfWeek), binToBcd(time.month),
                binToBcd(UInt8(time.year - 2000))]

            try? writeData(Register.secondStatus, data)
            try? writeRegister(Register.control3, Command.batteryMode.rawValue)
        }
    }

    /// Read current time. The time info is stored in a struct including the
    /// year, month, day, hour, minute, second, dayOfWeek. 
    /// - Returns: A Time struct if the communication is stable. Or it will be nil.
    public func readCurrent() -> Time? {
        try? readRegister(.secondStatus, into: &readBuffer, count: 7)

        let year = UInt16(bcdToBin(readBuffer[6])) + 2000
        let month = bcdToBin(readBuffer[5])
        let dayOfWeek = bcdToBin(readBuffer[4])
        let day = bcdToBin(readBuffer[3])
        let hour = bcdToBin(readBuffer[2])
        let minute = bcdToBin(readBuffer[1])
        let second = bcdToBin(readBuffer[0] & 0b0111_1111)

        let time = Time(
            year: year, month: month, day: day, hour: hour,
            minute: minute, second: second, dayOfWeek: dayOfWeek)
        return time
    }

    /// Enable the 1 second timer and generate an interrupt each second.
    public func enable1SecondTimer() {
        var byte: UInt8 = 0
        try? readRegister(Register.clockoutControl, into: &byte)
        try? writeRegister(Register.clockoutControl, byte | 0b1011_1000)

        try? readRegister(Register.control1, into: &byte)
        try? writeRegister(Register.control1, byte | 0b0100)
    }

    /// Disable the 1 second timer until you restart it.
    public func disable1SecondTimer() {
        var byte: UInt8 = 0
        try? readRegister(Register.control1, into: &byte)
        try? writeRegister(Register.control1, byte & 0b1111_1011)
    }

    /// Enable the countdown timer.
    ///
    /// The timer starts to count down from the specified value (1-255).
    /// The timer's period equals `countPeriod` x `count`.
    /// If the time for each count is 1s and the total count is 10, the timer
    ///  will generate interrupt every 10s.
    /// - Parameters:
    ///   - countPeriod: The time for each count.
    ///   - counts: The value from which the timer will start to count down.
    public func enableTimer(countPeriod: TimerCountPeriod, count: UInt8) {
        disable1SecondTimer()
        try? writeRegister(Register.control2, 0)
        try? writeRegister(Register.clockoutControl, 0)
        try? writeRegister(Register.timerBFre, 0)
        try? writeRegister(Register.timerBReg, 0)

        var interruptStatus: UInt8 = 0
        try? readRegister(Register.control2, into: &interruptStatus)
        var timerStatus: UInt8 = 0
        try? readRegister(Register.clockoutControl, into: &timerStatus)
        try? writeRegister(Register.control2, interruptStatus | 0b01)

        try? writeRegister(Register.timerBFre, countPeriod.rawValue)
        try? writeRegister(Register.timerBReg, count)
        try? writeRegister(Register.clockoutControl, timerStatus | 0b0111_1001)
    }

    /// Disable the countdown timer.
    public func disableTimer() {
        var byte: UInt8 = 0
        try? readRegister(Register.clockoutControl, into: &byte)
        try? writeRegister(Register.clockoutControl, byte & 0b1111_1110)
    }

    /// The period of the countdown timer source clock, that is, the time
    /// spent on each count.
    public enum TimerCountPeriod: UInt8 {
        /// The Timer clock frequency is 4.096kHz. The min timer's period is
        /// 244us, the max is 62.256ms.
        case us244 = 0
        /// The Timer clock frequency is 64Hz. The min timer's period is
        /// 15.625ms, the max is 3.984375s.
        case ms15 = 1
        /// The Timer clock frequency is 1Hz. The min timer's period is 1s,
        /// the max is 255s.
        case second = 2
        /// The Timer clock frequency is 1/60Hz. The min timer's period is 1min,
        /// the max is 255min.
        case minute = 3
        /// The Timer clock frequency is 1/3600Hz. The min timer's period is 1h,
        /// the max is 255h.
        case hour = 4
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
            year: UInt16, month: UInt8, day: UInt8, hour: UInt8,
            minute: UInt8, second: UInt8, dayOfWeek: UInt8
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


extension PCF8523 {

    private enum Register: UInt8 {
        case control1 = 0x00
        case control2 = 0x01
        case control3 = 0x02
        case clockoutControl = 0x0F
        case timerBFre = 0x12
        case timerBReg = 0x13
        case offset = 0x0E
        case secondStatus = 0x03
    }

    private enum Command: UInt8 {
        case reset = 0x58
        case batteryMode = 0x00

    }

    private func bcdToBin(_ value: UInt8) -> UInt8 {
        return value - 6 * (value >> 4)
    }

    private func binToBcd(_ value: UInt8) -> UInt8 {
        return value + 6 * (value / 10)
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

    private func lostPower() -> Bool {
        var byte: UInt8 = 0
        try? readRegister(Register.secondStatus, into: &byte)
        let stopFlag = byte >> 7
        return stopFlag == 1
    }
}
