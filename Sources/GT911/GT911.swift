//=== GT911.swift ---------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Andy Liu
// Created: 12/19/2024
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// A driver for the GT911 capacitive touch sensor, communicating via I2C.
public final class GT911 {
    private let i2c: I2C
    private let address: UInt8
    private var readBuffer = [UInt8](repeating: 0, count: 40)

    // MARK: - Public Types

    /// Enum representing the interrupt modes for the GT911 touch sensor.
    public enum InterruptMode: UInt8 {
        case rising = 0x00
        case falling = 0x01
        case lowLevel = 0x02
        case highLevel = 0x03
    }

    /// Initializes the GT911 touch sensor with the specified I2C instance and address.
    ///
    /// - Parameters:
    ///   - i2c: The I2C instance for communication.
    ///   - address: The I2C address of the GT911 sensor. Default value is `0xBA`.
    /// - Precondition: The I2C speed must be `.standard` (100kHz) or `.fast` (400kHz).
    public init(_ i2c: I2C, address: UInt8 = 0xBA) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            print(#function + ": GT911 only supports 100kHz (standard) and 400kHz (fast) I2C speed")
            fatalError()
        }

        self.i2c = i2c
        self.address = address >> 1

        softReset()
        sleep(ms: 20)
        clearStatus()
    }

    // MARK: - Public Methods

    /// Reads the product ID of the GT911 touch sensor.
    ///
    /// - Returns: A string representing the product ID, or `nil` if reading fails.
    public func readProductID() -> String? {
        var str: String?

        do {
            try readRegister(.productID, into: &readBuffer, count: 4)
            readBuffer.withUnsafeBufferPointer { buffer in
                str = String(cString: buffer.baseAddress!)
            }
        } catch {
            return nil
        }

        return str
    }

    /// Resets the touch sensor by issuing a soft reset command.
    public func softReset() {
        let data: UInt8 = 0x04

        try? writeRegister(.command, data)
    }

    /// Sets the number of touch points the sensor can detect.
    ///
    /// - Parameter number: The number of touch points (1 to 5).
    public func setTouchNumber(_ number: UInt8) {
        guard number >= 1, number <= 5 else {
            return
        }

        try? writeRegister(.touchNumber, number)
    }

    /// Reads the maximum X and Y output resolution supported by the touch sensor.
    ///
    /// - Returns: A tuple containing the X and Y maximum values.
    public func readOutputMax() -> (x: UInt16, y: UInt16) {
        var x: UInt16 = 0, y: UInt16 = 0

        try? readRegister(.xOutputMax, into: &x)
        try? readRegister(.yOutputMax, into: &y)

        return (x, y)
    }

    /// Sets the maximum X and Y output resolution.
    ///
    /// - Parameters:
    ///   - x: The maximum X value to set (optional).
    ///   - y: The maximum Y value to set (optional).
    public func setOutputMax(x: UInt16? = nil, y: UInt16? = nil) {
        if let x {
            try? writeRegister(.xOutputMax, x)
        }
        if let y {
            try? writeRegister(.yOutputMax, y)
        }
    }

    /// Reverses the X and Y axes for the touch coordinates.
    public func reverseXY() {
        var oldValue: UInt8 = 0
        try? readRegister(.moduleSwitch1, into: &oldValue)

        oldValue ^= 0x08
        try? writeRegister(.moduleSwitch1, oldValue)
    }

    /// Sets the interrupt mode for the touch sensor.
    ///
    /// - Parameter mode: The interrupt mode to set (`InterruptMode` enum).
    public func setInterruptMode(_ mode: InterruptMode) {
        var oldValue: UInt8 = 0
        try? readRegister(.moduleSwitch1, into: &oldValue)

        oldValue &= 0xFC
        oldValue |= mode.rawValue
        try? writeRegister(.moduleSwitch1, oldValue)
    }

    /// Reads the status register of the touch sensor.
    ///
    /// - Returns: The status register value.
    public func readStatus() -> UInt8 {
        var value: UInt8 = 0
        try? readRegister(.status, into: &value)

        return value
    }

    /// Clears the status register of the touch sensor.
    public func clearStatus() {
        try? writeRegister(.status, UInt8(0))
    }

    /// Reads the touch information and returns an array of touch points.
    ///
    /// - Returns: An array of `TouchInfo` structures containing touch point data.
    public func readTouchInfo() -> [TouchInfo] {
        var touchInfo = [TouchInfo]()

        let status = readStatus()

        if (status & 0x80) == 0 {
            return touchInfo
        } else if (status & 0x0F) == 0 {
            clearStatus()
            return touchInfo
        }

        let touchPointCount = Int(status & 0x0F)
        try! readRegister(.bufferStart, into: &readBuffer, count: touchPointCount * 8)

        for i in 0 ..< touchPointCount {
            touchInfo.append(getTouchPosition(at: i))
        }

        clearStatus()

        return touchInfo
    }
}

extension GT911 {
    private enum Register: UInt16 {
        case command = 0x8040
        case xOutputMax = 0x8048
        case yOutputMax = 0x804A
        case touchNumber = 0x804C
        case moduleSwitch1 = 0x804D
        case touchLevel = 0x8053
        case leaveLevel = 0x8054

        case productID = 0x8140
        case firmwareVer = 0x8144
        case status = 0x814E
        case bufferStart = 0x814F

        func getRawData() -> [UInt8] {
            let highByte = UInt8(rawValue >> 8)
            let lowByte = UInt8(rawValue & 0xFF)

            return [highByte, lowByte]
        }
    }

    private func getTouchPosition(at index: Int) -> TouchInfo {
        var index = index * 8

        let id = readBuffer[index]

        index += 1
        let x = 320 - (UInt16(readBuffer[index]) | (UInt16(readBuffer[index + 1]) << 8))

        index += 2
        let y = UInt16(readBuffer[index]) | (UInt16(readBuffer[index + 1]) << 8)

        index += 2
        let size = UInt16(readBuffer[index]) | (UInt16(readBuffer[index + 1]) << 8)

        return TouchInfo(id: id, x: x, y: y, size: size)
    }

    private func writeRegister(_ register: Register, _ value: UInt8) throws(Errno) {
        var data = register.getRawData()
        data.append(value)

        let result = i2c.write(data, to: address)
        if case let .failure(err) = result {
            throw err
        }
    }

    private func writeRegister(_ register: Register, _ value: UInt16) throws(Errno) {
        var data = register.getRawData()

        let lowByte = UInt8(value & 0xFF)
        let highByte = UInt8(value >> 8)
        data.append(lowByte)
        data.append(highByte)

        let result = i2c.write(data, to: address)
        if case let .failure(err) = result {
            throw err
        }
    }

    private func readRegister(
        _ register: Register, into byte: inout UInt8
    ) throws(Errno) {
        var result = i2c.write(register.getRawData(), to: address)
        if case let .failure(err) = result {
            throw err
        }

        result = i2c.read(into: &byte, from: address)
        if case let .failure(err) = result {
            throw err
        }
    }

    private func readRegister(
        _ register: Register, into value: inout UInt16
    ) throws(Errno) {
        for i in readBuffer.indices {
            readBuffer[i] = 0
        }

        var result = i2c.write(register.getRawData(), to: address)
        if case let .failure(err) = result {
            throw err
        }

        result = i2c.read(into: &readBuffer, count: 2, from: address)
        if case let .failure(err) = result {
            throw err
        }

        value = UInt16(readBuffer[0]) | (UInt16(readBuffer[1]) << 8)
    }

    private func readRegister(
        _ register: Register, into buffer: inout [UInt8], count: Int
    ) throws(Errno) {
        for i in buffer.indices {
            buffer[i] = 0
        }

        var result = i2c.write(register.getRawData(), to: address)
        if case let .failure(err) = result {
            throw err
        }

        result = i2c.read(into: &buffer, count: count, from: address)
        if case let .failure(err) = result {
            throw err
        }
    }
}
