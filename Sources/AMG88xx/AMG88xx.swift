//=== AMG88xx.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 06/25/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for AMG88xx infrared thermal sensor.
///
/// The sensor detects IR radiation emitted from all kinds of sources, including
/// human body. It provides temperature detection of two-dimensional area: 8x8
/// (64 pixels) and 60° viewing angle. It returns 64 temperature readings
/// via I2C bus.
///
/// There are several types of sensor in AMG88xx series. They need different
/// operating voltage and have a different measuring range and precision.
final public class AMG88xx {
    private let i2c: I2C
    private let address: UInt8
    private var readBuffer = [UInt8](repeating: 0, count: 128)

    /// Initialize the sensor using I2C communication.
    ///
    /// If the address pin is connected to GND, the sensor's address is 0x68. If
    /// it's connected to power, the address is 0x69.
    /// - Parameters:
    ///   - i2c: **REQUIRED** An I2C interface the sensor is connected to.
    ///   - address: **OPTIONAL** The sensor's address, 0x69 by default.
    public init(_ i2c: I2C, address: UInt8 = 0x69) {
        self.i2c = i2c
        self.address = address

        /// Set normal mode.
        try? writeRegister(.pclt, 0x00)
        /// Reset the sensor.
        try? writeRegister(.rst, 0x3F)
        /// Disable interrupt.
        try? writeRegister(.intc, 0x00)
        /// Set 10 FPS (frame per second).
        try? writeRegister(.fpsc, 0x00)
    }

    /// Read the temperature of the sensor in Celsius.
    /// - Returns: A float representing temperature in Celsius.
    public func readTemperature() -> Float {
        try? readRegister(.tthl, into: &readBuffer, count: 2)
        let lsb = readBuffer[0]
        let msb = readBuffer[1]

        let absTemp = Float(UInt16(lsb) | UInt16(msb & 0x7) << 8) * 0.0625

        if msb & 0b1000 != 0 {
            return -absTemp
        } else {
            return absTemp
        }
    }

    /// Read temperatures of 8x8 pixels in Celsius and return them in an array.
    /// - Returns: An array of temperature readings.
    public func readPixels() -> [Float] {
        var pixels = [Float](repeating: 0, count: 64)

        try? readRegister(.t01l, into: &readBuffer, count: 128)
        for i in 0..<64 {
            pixels[i] = Float(calculateRaw(readBuffer[i*2], readBuffer[i*2+1])) * 0.25
        }
        return pixels
    }

    /// Read temperatures of 8x8 pixels in Celsius and store the values in the
    /// buffer you pass in.
    /// - Parameter buffer: An array to store the temperature readings.
    public func readPixels(_ buffer: inout [Float]) {
        guard buffer.count >= 64 else {
            print(#function + ": buffer size should not be smaller than 64.")
            return
        }

        try? readRegister(.t01l, into: &readBuffer, count: 128)
        for i in 0..<64 {
            buffer[i] = Float(calculateRaw(readBuffer[i*2], readBuffer[i*2+1]))  * 0.25
        }
    }

    /// Read raw values of 8x8 pixels and store them in the buffer you pass in.
    /// - Parameter buffer: An array to store the raw values.
    public func readRawPixels(_ buffer: inout [Int]) {
        try? readRegister(.t01l, into: &readBuffer, count: 128)
        for i in 0..<64 {
            buffer[i] = calculateRaw(readBuffer[i*2], readBuffer[i*2+1])
        }
    }
}

extension AMG88xx {
    enum Register: UInt8 {
        case pclt = 0x00
        case rst = 0x01
        case fpsc = 0x02
        case intc = 0x03
        case tthl = 0x0E
        case tthh = 0x0F
        case t01l = 0x80
    }

    private func readRegister(
        _ register: Register, into buffer: inout [UInt8], count: Int
    ) throws {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        let result = i2c.writeRead(register.rawValue, into: &buffer, readCount: count, address: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func writeRegister(_ register: Register, _ value: UInt8) throws {
        let result = i2c.write([register.rawValue, value], to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func calculateRaw(_ lsb: UInt8, _ msb: UInt8) -> Int {
        var rawTemp = Int16(lsb) | Int16(msb) << 8
        if msb & 0b1000 != 0 {
            rawTemp -= 0x1000
        }

        return Int(rawTemp)
    }
}
