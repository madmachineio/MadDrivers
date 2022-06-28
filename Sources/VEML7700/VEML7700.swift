//=== VEML7700.swift ------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 05/31/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for VEML7700 light sensor. It supports I2C communication.
///
/// The sensor contains a high sensitive photodiode for light measurement,
/// and some other components for the final digital readings.
/// It supports 16-bit dynamic range for ambient light detection
/// from 0 lux to about 120k lux with resolution down to 0.0036 lx/ct.
///
/// It provides ways to adjust the sensor for measurement - you can change the
/// gain or integration time setting according to your environment.
final public class VEML7700 {
    private let i2c: I2C
    private let address: UInt8

    var gain: Gain
    var integrationTime: IntegrationTime

    private var readBuffer = [UInt8](repeating: 0, count: 2)

    var resolution: Float {
        let gainValue = gain.value
        let integrationTime = integrationTime.ms

        return 0.0036 * (Gain.x2.value / gainValue) *
                Float((IntegrationTime.ms800.ms / integrationTime))
    }

    /// Initialize the sensor using I2C communication. It set a default integration time of 100ms and a default gain of x1.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects. The
    ///   maximum I2C speed is 400KHz (fast).
    ///   - address: **OPTIONAL** The sensor's address, 0x10 by default.
    public init(_ i2c: I2C, address: UInt8 = 0x10) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": VEML7700 only supports 100kHz (standard) and 400kHz (fast) I2C speed")
        }

        self.i2c = i2c
        self.address = address

        gain = .x1
        integrationTime = .ms100

        powerOn()

        setGain(gain)
        setIntegrationTime(integrationTime)
    }

    /// Read the ambient light and represent it in lux.
    /// - Returns: A float representing the light intensity in lux.
    public func readLux() -> Float {
        return Float(readLight()) * resolution
    }

    /// Read 16-bit raw value of ambient light.
    ///
    /// The reading tells roughly the amount of ambient light and has no unit.
    /// And it will change with the gain and integration time settings.
    /// - Returns: A raw value in UInt16 representing the ambient light intensity.
    public func readLight() -> UInt16 {
        try? readRegister(.als, into: &readBuffer)
        return UInt16(readBuffer[0]) | UInt16(readBuffer[1]) << 8
    }

    /// Read 16-bit raw value of white light.
    ///
    /// The reading tells roughly the amount of white light and has no unit.
    /// And it will change with the gain and integration time settings.
    /// - Returns: A raw value in UInt16 representing the amount of white light.
    public func readWhite() -> UInt16 {
        try? readRegister(.white, into: &readBuffer)
        return UInt16(readBuffer[0]) | UInt16(readBuffer[1]) << 8
    }


    /// Set the gain for the measurement to set how the signal is amplified.
    /// - Parameter gain: A gain setting in ``Gain``.
    public func setGain(_ gain: Gain) {
        try? readRegister(.configuration, into: &readBuffer)

        try? writeRegister(.configuration, [readBuffer[0],
                                            readBuffer[1] & 0b1110_0111 | (gain.rawValue << 3)])
        self.gain = gain
    }

    /// Get the current gain setting.
    /// - Returns: A gain setting in ``Gain``.
    func getGain() -> Gain {
        return gain
    }


    /// The gain setting to set how the signal will be amplified for the measurement.
    public enum Gain: UInt8 {
        /// 1x gain.
        case x1 = 0
        /// 2x gain.
        case x2 = 1
        /// 0.125x gain.
        case eighth = 2
        /// 0.25x gain.
        case quarter = 3

        /// The gain value for lux calculation.
        var value: Float {
            switch self {
            case .x1:
                return 1
            case .x2:
                return 2
            case .quarter:
                return 0.25
            case .eighth:
                return 0.125
            }
        }
    }

    /// Set the integration time for light measurement.
    /// - Parameter time: A time setting in the ``IntegrationTime``.
    public func setIntegrationTime(_ time: IntegrationTime) {
        try? readRegister(.configuration, into: &readBuffer)

        let lsb = readBuffer[0] & 0b0011_1111 | (time.rawValue & 0b0011) << 6
        let msb = readBuffer[1] & 0b1111_1100 | (time.rawValue >> 2)

        try? writeRegister(.configuration, [lsb, msb])
        self.integrationTime = time
    }

    /// Get the current integration time for light measurement.
    /// - Returns: A time setting in the ``IntegrationTime``.
    func getIntegrationTime() -> IntegrationTime {
        return integrationTime
    }

    /// The integration time setting for the measurement. 
    public enum IntegrationTime: UInt8 {
        case ms25 = 0b1100
        case ms50 = 0b1000
        case ms100 = 0b0000
        case ms200 = 0b0001
        case ms400 = 0b0010
        case ms800 = 0b0011

        /// The integration time for lux calculation.
        var ms: Int {
            switch self {
            case .ms25:
                return 25
            case .ms50:
                return 50
            case .ms100:
                return 100
            case .ms200:
                return 200
            case .ms400:
                return 400
            case .ms800:
                return 800
            }
        }
    }
}


extension VEML7700 {
    enum Register: UInt8 {
        case configuration = 0x00
        case als = 0x04
        case white = 0x05
    }

    private func readRegister(
        _ register: Register, into buffer: inout [UInt8]
    ) throws {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        let result = i2c.writeRead(register.rawValue, into: &buffer, address: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func writeRegister(_ register: Register, _ data: [UInt8]) throws {
        var data = data
        data.insert(register.rawValue, at: 0)
        let result = i2c.write(data, to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func powerOn() {
        try? readRegister(.configuration, into: &readBuffer)
        try? writeRegister(.configuration, [readBuffer[0] & 0b1111_1110, readBuffer[1]])
        sleep(ms: 5)
    }
}
