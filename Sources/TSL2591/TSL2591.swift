//=== TSL2591.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 04/02/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for TSL2591 light sensor. It supports I2C communication.
///
/// This sensor contains two photodiodes: one responds to both visible and IR
/// light (full spectrum), and the other responds only to IR light.
///
/// It can measure light intensity up to 88000 lux. The lux is a measure of
/// light intensity based on human vision. The raw values from the sensor can be
/// calculated approximately into lux using an empirical formula.
///
/// You can set its sensitivity to light by changing gain and integration time
/// according to your ambient light.
final public class TSL2591 {
    private let i2c: I2C
    private let address: UInt8

    private var commandBit: UInt8 = 0xA0

    private var gain: Gain
    private var integrationTime: IntegrationTime

    private var aGain: Float {
        switch gain {
        case .low:
            return 1
        case .medium:
            return 25
        case .high:
            return 428
        case .maximum:
            return 9876
        }
    }

    private var maxCount: UInt16 {
        switch integrationTime {
        case .ms100:
            return 36863
        default:
            return 65535
        }
    }

    private var readBuffer = [UInt8](repeating: 0, count: 2)

    /// Initialize the sensor using I2C communication.
    /// The default integration time is 100ms and the gain is `.medium`.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   - address: **OPTIONAL** The device address of the sensor.
    ///   0x29 by default.
    public init(_ i2c: I2C, address: UInt8 = 0x29) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            print(#function + ": TSL2591 only supports 100kHz (standard) and 400kHz (fast) I2C speed")
            fatalError()
        }

        self.i2c = i2c
        self.address = address

        gain = .medium
        integrationTime = .ms100

        guard getDeviceID() == 0x50 else {
            print(#function + ": Fail to find TSL2591 at address \(address)")
            fatalError()
        }

        setGain(gain)
        setIntegrationTime(integrationTime)
        enable()
    }

    /// Read full sepctrum light intensity in lux.
    /// - Returns: The light intensity in lux.
    public func readLux() -> Float {
        let values = readRaw()
        let aTime = 100 * Float(integrationTime.rawValue) + 100

        if values.0 >= maxCount || values.1 >= maxCount {
            print("Raw reading overflow. Please reduce the gain \(gain).")
        }

        let channel0 = Float(values.0)
        let channel1 = Float(values.1)

        let cpl = aTime * aGain / Coefficient.df.rawValue
        let lux1 = (channel0 - Coefficient.coeffB.rawValue * channel1) / cpl
        let lux2 = (Coefficient.coeffC.rawValue * channel0 -
                    Coefficient.coeffD.rawValue * channel1) / cpl
        return max(lux1, lux2)
    }

    /// Read intensity of full spectrum light. It includes IR and visible light.
    /// - Returns: A raw value representing the light intensity.
    public func readFullSpectrum() -> UInt32 {
        let value = readRaw()
        return UInt32(value.1) << 16 | UInt32(value.0)
    }

    /// Read the IR light intensity.
    /// - Returns: A raw value representing the IR light intensity.
    public func readIR() -> UInt16 {
        return readRaw().1
    }

    /// Read the visible light intensity.
    /// - Returns: A raw value representing the visible light intensity.
    public func readVisible() -> UInt32 {
        let value = readRaw()
        return UInt32(value.1) << 16 | UInt32(value.0) - UInt32(value.1)
    }

    /// Set the gain of the sensor.
    /// - Parameter gain: A gain in the enum `Gain`: `low`, `medium`, `high`, `maximum`.
    public func setGain(_ gain: Gain) {
        self.gain = gain
        var control: UInt8 = 0
        try? readRegister(.control, into: &control)
        control = control & 0b11001111 | (gain.rawValue << 4)
        try? writeRegister(.control, control)
    }

    /// Get the gain setting of the sensor.
    /// - Returns: A gain in the enum `Gain`: `low`, `medium`, `high`, `maximum`.
    public func getGain() -> Gain {
        var control: UInt8 = 0
        try? readRegister(.control, into: &control)
        gain = Gain(rawValue: (control & 0b00110000) >> 4)!
        return gain
    }

    /// Set the integration time of the sensor.
    /// - Parameter time: A time in the enum `IntegrationTime`: `ms100`, `ms200`,
    /// `ms300`, `ms400`, `ms500`, `ms600`.
    public func setIntegrationTime(_ time: IntegrationTime) {
        self.integrationTime = time
        var control: UInt8 = 0
        try? readRegister(.control, into: &control)
        control = control & 0b11111000 | time.rawValue
        try? writeRegister(.control, control)
    }

    /// Get the integration time of the sensor.
    /// - Returns: A time in the enum `IntegrationTime`: `ms100`, `ms200`,
    /// `ms300`, `ms400`, `ms500`, `ms600`.
    public func getIntegrationTime() -> IntegrationTime {
        var control: UInt8 = 0
        try? readRegister(.control, into: &control)
        integrationTime = IntegrationTime(rawValue: control & 0b0111)!
        return integrationTime
    }

    /// The integration time of the sensor. The longer the time, the more
    /// sensitive the sensor in low light.
    public enum IntegrationTime: UInt8 {
        /// 100ms integration time, 36863 max count.
        case ms100 = 0
        /// 200ms integration time, 65535 max count.
        case ms200 = 1
        /// 300ms integration time, 65535 max count.
        case ms300 = 2
        /// 400ms integration time, 65535 max count.
        case ms400 = 3
        /// 500ms integration time, 65535 max count.
        case ms500 = 4
        /// 600ms integration time, 65535 max count.
        case ms600 = 5
    }

    /// The gain for the internal amplifiers for measurement.
    public enum Gain: UInt8 {
        /// x1, for bright light.
        case low = 0
        /// x25, the default setting.
        case medium = 1
        /// x428, for low light.
        case high = 2
        /// x9876, for extemely low light.
        case maximum = 3
    }
}

extension TSL2591 {
    enum Register: UInt8 {
        case enable = 0x00
        case control = 0x01
        case deviceID = 0x12
        case C0DATAL = 0x14
        case C1DATAL = 0x16
    }

    enum Coefficient: Float {
        case df = 408
        case coeffB = 1.64
        case coeffC = 0.59
        case coeffD = 0.86
    }

    private func readRegister(
        _ register: Register, into byte: inout UInt8
    ) throws(Errno) {
        var result = i2c.write(register.rawValue | commandBit, to: address)
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

        var result = i2c.write(register.rawValue | commandBit, to: address)
        if case .failure(let err) = result {
            throw err
        }

        result = i2c.read(into: &buffer, count: count, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func writeRegister(_ register: Register, _ value: UInt8) throws(Errno) {
        let result = i2c.write([register.rawValue | commandBit, value], to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func getDeviceID() -> UInt8 {
        var byte: UInt8 = 0
        try? readRegister(.deviceID, into: &byte)
        return byte
    }

    /// Power on and enable No Persist Interrupt, ALS Interrupt, ALS.
    func enable() {
        try? writeRegister(.enable, 0b10010011)
    }

    func readRaw() -> (UInt16, UInt16) {
        try? readRegister(.C0DATAL, into: &readBuffer, count: 2)
        let channel0 = UInt16(readBuffer[1]) << 8 | UInt16(readBuffer[0])

        try? readRegister(.C1DATAL, into: &readBuffer, count: 2)
        let channel1 = UInt16(readBuffer[1]) << 8 | UInt16(readBuffer[0])
        return (channel0, channel1)
    }
}
