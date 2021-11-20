//=== PCF8523.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 11/20/2021
// Updated: 11/20/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

final public class PCF8523 {
    private let i2c: I2C
    private let address: UInt8

    /// Initialize the RTC.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface the RTC connects to.
    ///   - address: **OPTIONAL** The sensor's address. It has a default value.
    public init(_ i2c: I2C, _ address: UInt8 = 0x68) {
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
        let reading = lostPower()
        if let reading = reading {
            if reading || update {
                let data = [
                    binToBcd(time.second), binToBcd(time.minute),
                    binToBcd(time.hour), binToBcd(time.day),
                    binToBcd(time.dayOfWeek), binToBcd(time.month),
                    binToBcd(UInt8(time.year - 2000))]

                writeData(Register.secondStatus, data)
                writeRegister(Register.control3, Command.batteryMode.rawValue)
            }
        }
    }

    /// Read current time. The time info is stored in a struct including the
    /// year, month, day, hour, minute, second, dayOfWeek. 
    /// - Returns: A Time struct if the communication is stable. Or it will be nil.
    public func readCurrent() -> Time? {
        i2c.write(Register.secondStatus.rawValue, to: address)
        let data = i2c.read(count: 7, from: address)

        if data.count != 7 {
            print("readCurrent error")
            return nil
        } else {
            let year = UInt16(bcdToBin(data[6])) + 2000
            let month = bcdToBin(data[5])
            let dayOfWeek = bcdToBin(data[4])
            let day = bcdToBin(data[3])
            let hour = bcdToBin(data[2])
            let minute = bcdToBin(data[1])
            let second = bcdToBin(data[0] & 0b0111_1111)

            let time = Time(
                year: year, month: month, day: day, hour: hour,
                minute: minute, second: second, dayOfWeek: dayOfWeek)
            return time
        }
    }

    /// Enable the 1 second timer and generate an interrupt each second.
    public func enable1SecondTimer() {
        let timerStatus = readRegister(Register.clockoutControl)

        if let timerStatus = timerStatus {
            writeRegister(Register.clockoutControl, timerStatus | 0b1011_1000)
        } else {
            print("read clockoutControl register error")
        }

        let interruptStatus = readRegister(Register.control1)

        if let interruptStatus = interruptStatus {
            writeRegister(Register.control1, (interruptStatus | 0b0100))
        } else {
            print("read control1 register error")
        }
    }

    /// Disable the 1 second timer until you restart it.
    public func disable1SecondTimer() {
        let interruptStatus = readRegister(Register.control1)
        if let interruptStatus = interruptStatus {
            writeRegister(Register.control1, interruptStatus & 0b1111_1011)
        } else {
            print("read control1 register error")
        }
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
        writeRegister(Register.control2, 0)
        writeRegister(Register.clockoutControl, 0)
        writeRegister(Register.timerBFre, 0)
        writeRegister(Register.timerBReg, 0)

        let interruptStatus = readRegister(Register.control2)
        let timerStatus = readRegister(Register.clockoutControl)

        if let interruptStatus = interruptStatus {
            writeRegister(Register.control2, interruptStatus | 0b01)
        } else {
            print("read control2 register error")
        }

        let frequency = countPeriod.rawValue
        writeRegister(Register.timerBFre, frequency)
        writeRegister(Register.timerBReg, count)

        if let timerStatus = timerStatus {
            writeRegister(Register.clockoutControl, timerStatus | 0b0111_1001)
        } else {
            print("read clockoutControl register error")
        }
    }

    /// Disable the countdown timer.
    public func disableTimer() {
        let timerStatus = readRegister(Register.clockoutControl)

        if let timerStatus = timerStatus {
            writeRegister(Register.clockoutControl, timerStatus & 0b1111_1110)
        } else {
            print("read clockoutControl register error")
        }
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
    public func isRunning() -> Bool? {
        let data = readRegister(Register.control1)
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

    /// Make the clock start to work so the time will keep updated.
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

    /// Stop the internal clock, and the time you read from the RTC will not
    /// be accurate anymore.
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

    private func lostPower() -> Bool? {
        let data = readRegister(Register.secondStatus)
        var stopFlag: UInt8 = 2

        if let data = data {
            stopFlag = data >> 7
        } else {
            print("read power status error")
            return nil
        }

        if stopFlag == 1 {
            return true
        } else {
            return false
        }
    }
}
