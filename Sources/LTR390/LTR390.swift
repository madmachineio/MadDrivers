//=== BMP280.swift --------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 05/13/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO
// import RealModule

/// This is the library for LTR390 UV and ambient light sensor.
///
/// The sensor has photodiodes for UV and ambient light measurement. It measures
/// light intensity and converts it into signals that can be read using I2C
/// communication. With the raw values from the sensor, you can also get the
/// UV index and lux level.
///
/// It provides ways to adjust the sensor for measurement - you can change the
/// gain setting or internal ADC resolution.
final public class LTR390 {
    private let i2c: I2C
    private let address: UInt8

    private var mode: Mode = .als
    private var gain: Gain
    private var resolution: Resolution

    private var readBuffer = [UInt8](repeating: 0, count: 3)

    /// Compensate light loss due to the lower transmission if there is a tinted window.
    /// 1 means no window or a clear window glass.
    /// If there is a tinted window, the factor should be bigger than 1.
    private var windowFactor: Float = 1

    /// Initialize the sensor using I2C communication.
    ///
    /// The sensor supports 100kHz (standard) and 400kHz (fast) I2C speed.
    ///
    /// By default, it adopts 3x `Gain` setting and 16-bit `Resolution`
    /// for measurement. You could change them using ``setGain(_:)`` and
    /// ``setResolution(_:)``.
    /// 
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects. The maximum
    ///   I2C speed is 400KHz (fast).
    ///   - address: **OPTIONAL** The device address of the sensor, 0x53 by default.
    public init(_ i2c: I2C, address: UInt8 = 0x53) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            print(#function + ": LTR390 only supports 100kHz (standard) and 400kHz (fast) I2C speed")
            fatalError()
        }

        self.i2c = i2c
        self.address = address

        gain = .x3
        resolution = .bit16

        guard getID() == 0xB2 else {
            print(getID())
            print(#function + ": Fail to find LTR390 at address \(address)")
            fatalError()
        }

        reset()
        enable()

        if !enabled() {
            print(#function + ": Fail to activate the sensor LTR390")
        }

        setMode(.uvs)
        setGain(gain)
        setResolution(resolution)
    }

    /// Read the amount of UV light and calculate the UV index.
    /// 
    /// - Returns: UV index in Float.
    public func readUVI() -> Float {
        let uv = Float(readUV())

        let sensitivity = 2300 * (gain.factor() / 18) *
        Float.exp2(resolution.factor() - 20)

        return uv / sensitivity * windowFactor
    }

    /// Read raw value of UV light. The reading tells roughly the amount of UV
    /// light and has no unit.
    /// - Returns: UV raw value in UInt32.
    public func readUV() -> UInt32 {
        setMode(.uvs)
        
        while !isDtatReady() {
            sleep(ms: 10)
        }

        try? readRegister(.UVS_DATA_0, into: &readBuffer, count: 3)
        return calculateUInt32(readBuffer)
    }

    /// Read raw value of ambient light.
    /// The reading tells roughly the amount of ambient light and has no unit.
    /// - Returns: Raw value in UInt32 representing the ambient light intensity.
    public func readLight() -> UInt32 {
        setMode(.als)

        while !isDtatReady() {
            sleep(ms: 10)
        }

        try? readRegister(.ALS_DATA_0, into: &readBuffer, count: 3)
        return calculateUInt32(readBuffer)
    }

    /// Read light intensity and calculate the lux level.
    /// - Returns: Lux level in Float.
    public func readLux() -> Float {
        let light = Float(readLight())
        return (light * 0.6 / (gain.factor() * resolution.integration())) * windowFactor
    }

    /// Set the resolution for measurement. The raw value from the sensor will
    /// change with it.
    /// - Parameter resolution: A resolution setting in ``Resolution``.
    public func setResolution(_ resolution: Resolution) {
        var byte: UInt8 = 0
        try? readRegister(.MEAS_RATE, into: &byte)
        try? writeRegister(.MEAS_RATE, byte & 0b1000_1111 | (resolution.rawValue << 4))
        self.resolution = resolution
    }

    /// Get the resolution setting.
    /// - Returns: A resolution setting in ``Resolution``.
    public func getResolution() -> Resolution {
        var byte: UInt8 = 0
        try? readRegister(.MEAS_RATE, into: &byte)
        return Resolution(rawValue: (byte & 0b0111_0000) >> 4)!
    }

    /// The resolution settings for internal ADC.
    /// The default resolution is `bit16`.
    ///
    /// The raw values from the sensor range from 13 bits to 20 bits.
    /// Mmore bits ensure more accuracy but require a bit more time.
    public enum Resolution: UInt8 {
        /// 20 bits are used to store readings.
        case bit20 = 0
        /// 19 bits are used to store readings.
        case bit19 = 1
        /// 18 bits are used to store readings.
        case bit18 = 2
        /// 17 bits are used to store readings.
        case bit17 = 3
        /// 16 bits are used to store readings.
        case bit16 = 4
        /// 13 bits are used to store readings.
        case bit13 = 5

        /// Get the integration factor to calculate the lux.
        func integration() -> Float {
            switch self {
            case .bit20: return 4.0
            case .bit19: return 2.0
            case .bit18: return 1.0
            case .bit17: return 0.5
            case .bit16: return 0.25
            case .bit13: return 0.03125
            }
        }

        /// Get the integration factor to calculate the UV index.
        func factor() -> Float {
            switch self {
            case .bit20: return 20
            case .bit19: return 19
            case .bit18: return 18
            case .bit17: return 17
            case .bit16: return 16
            case .bit13: return 13
            }
        }
    }

    /// Change the gain setting for the measurement. The raw value from the
    /// sensor will change with it.
    /// - Parameter gain: A gain setting in ``Gain``.
    public func setGain(_ gain: Gain) {
        try? writeRegister(.GAIN, gain.rawValue)
        self.gain = gain
    }

    /// Get the gain setting for the measurement.
    /// - Returns: A gain setting in ``Gain``.
    public func getGain() -> Gain {
        var gain: UInt8 = 0
        try? readRegister(.GAIN, into: &gain)
        return Gain(rawValue: gain)!
    }

    /// The gain settings to change sensor's sensitivity.
    /// The default setting is `x3`.
    ///
    /// The gain settings are 1x, 3x, 6x, 9x, 18x. The raw values from the sensor
    /// change with it. For example, if you change gain from x1 to x3, the raw
    /// values should treple.
    public enum Gain: UInt8 {
        case x1 = 0
        case x3 = 1
        case x6 = 2
        case x9 = 3
        case x18 = 4

        /// Get the gain factor to calculate UVI and lux.
        func factor() -> Float {
            switch self {
            case .x1: return 1
            case .x3: return 3
            case .x6: return 6
            case .x9: return 9
            case .x18: return 18
            }
        }
    }
}


extension LTR390 {
    enum Register: UInt8 {
        case CTRL = 0x00
        case ID = 0x06
        case MEAS_RATE = 0x04
        case GAIN = 0x05
        case STATUS = 0x07
        case ALS_DATA_0 = 0x0D
        case UVS_DATA_0 = 0x10
        case INT_CFG = 0x19
        case INT_PST = 0x1A
        case THRESH_UP_0 = 0x21
        case THRESH_LOW_0 = 0x24

    }

    private func readRegister(
        _ register: Register, into byte: inout UInt8
    ) throws(Errno) {
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
    ) throws(Errno) {
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

    private func writeRegister(_ register: Register, _ value: UInt8) throws(Errno) {
        let result = i2c.write([register.rawValue, value], to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func writeRegister(_ register: Register, _ data: [UInt8]) throws(Errno) {
        var data = data
        data.insert(register.rawValue, at: 0)
        let result = i2c.write(data, to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func getID() -> UInt8 {
        var byte: UInt8 = 0
        try? readRegister(.ID, into: &byte)
        return byte
    }

    func reset() {
        try? writeRegister(.CTRL, 0x00)
        try? writeRegister(.MEAS_RATE, 0x22)
        try? writeRegister(.GAIN, 0x01)
        try? writeRegister(.INT_CFG, 0x10)
        try? writeRegister(.INT_PST, 0x00)
        try? writeRegister(.THRESH_UP_0, [0xFF, 0xFF, 0x0F])
        try? writeRegister(.THRESH_LOW_0, [0x00, 0x00, 0x00])
    }

    func enable() {
        var control: UInt8 = 0
        try? readRegister(.CTRL, into: &control)
        try? writeRegister(.CTRL, control | 0b10)
    }

    func enabled() -> Bool {
        var control: UInt8 = 0
        try? readRegister(.CTRL, into: &control)

        return control & 0b10 != 0
    }

    func isDtatReady() -> Bool {
        var status: UInt8 = 0
        try? readRegister(.STATUS, into: &status)
        return status & 0b1000 != 0
    }

    func calculateUInt32(_ bytes: [UInt8]) -> UInt32 {
        return UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16
    }


    func setMode(_ mode: Mode) {
        if mode != self.mode {
            var control: UInt8 = 0
            try? readRegister(.CTRL, into: &control)
            try? writeRegister(.CTRL, control & 0b1111_0111 | (mode.rawValue << 3))
            self.mode = mode
        }
    }

    func getMode() -> Mode {
        var control: UInt8 = 0
        try? readRegister(.CTRL, into: &control)
        return Mode(rawValue: (control & 0b1000) >> 3)!
    }

    enum Mode: UInt8 {
        case als = 0
        case uvs = 1
    }
}


@_extern(c, "exp2f")
func exp2f(_: Float) -> Float

extension Float {
  @_transparent
  static func exp2(_ x: Float) -> Float {
    exp2f(x)
  }
}