//=== TCS34725.swift ------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 04/09/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//
import SwiftIO
// import RealModule

/// This is the library for TCS34725 color sensor. It supports I2C communication.
///
/// The sensor contains photodiodes to sense red, green, blue and clear light. It has IR blocking filter to provide you with more accurate readings. According to your ambient light, you can also adjust the integration time and gain settings.
///
/// The final color reading might not be as accurate as you think. It is influenced by many factors, like ambient light, distance, etc.
final public class TCS34725 {
    private let i2c: I2C
    private let address: UInt8

    private let commandBit: UInt8 = 0x80

    private var integrationTime: Float
    private var gain: Gain
    private var glassAttenuation: Float = 1

    private var readBuffer = [UInt8](repeating: 0, count: 2)

    /// Initialize the sensor using I2C communication.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   - address: **OPTIONAL** The device address of the sensor.
    public init(_ i2c: I2C, address: UInt8 = 0x29) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            print(#function + ": TCS34725 only supports 100kHz (standard) and 400kHz (fast) I2C speed")
            fatalError()
        }

        self.i2c = i2c
        self.address = address

        integrationTime = 2.4
        gain = .x1

        guard getID() == 0x44 || getID() == 0x10 else {
            print(#function + ": Fail to find TCS34725 at address \(address)")
            fatalError()
        }

        setIntegrationTime(integrationTime)
        setGain(.x1)
    }

    /// Read RGBC color raw values.
    /// - Returns: Red, green, blue and clear raw value in UInt16.
    public func readRaw() -> (red: UInt16, green: UInt16, blue: UInt16, clear: UInt16) {

        enable()

        var status: UInt8 = 0
        repeat {
            try? readRegister(.status, into: &status)
            sleep(ms: Int(integrationTime + 0.9))
        } while status & 0x01 == 0

        try? readRegister(.rDataL, into: &readBuffer, count: 2)
        let red = UInt16(readBuffer[0]) | UInt16(readBuffer[1]) << 8

        try? readRegister(.gDataL, into: &readBuffer, count: 2)
        let green = UInt16(readBuffer[0]) | UInt16(readBuffer[1]) << 8

        try? readRegister(.bDataL, into: &readBuffer, count: 2)
        let blue = UInt16(readBuffer[0]) | UInt16(readBuffer[1]) << 8

        try? readRegister(.cDataL, into: &readBuffer, count: 2)
        let clear = UInt16(readBuffer[0]) | UInt16(readBuffer[1]) << 8

        disable()

        return (red, green, blue, clear)
    }

    /// Read color values and calculate the light intensity in lux.
    /// - Returns: The light intensity in lux.
    public func readLux() -> Float {
        let (red, green, blue, clear) = readRaw()
        return calculateTempLux(r: red, g: green, b: blue, c: clear).lux
    }

    /// Read color values and calculate the color temperature.
    /// - Returns: Color temperature in degrees of Kelvin (K).
    public func readColorTemperature() -> Float {
        let (red, green, blue, clear) = readRaw()
        return calculateTempLux(r: red, g: green, b: blue, c: clear).temp
    }

    /// Read color values and calculate them into color code, 8-bit for RGB colors respectively.
    /// - Returns: Color code in UInt32.
    public func readColorCode() -> UInt32 {
        let (red, green, blue, clear) = readRaw()
        return calculateRBG888(r: red, g: green, b: blue, c: clear)
    }

    /// Set the gain for the measurement.
    /// - Parameter gain: A gain in enum `Gain`: `.x1`, `.x4`, `.x16`, `.x60`.
    public func setGain(_ gain: Gain) {
        try? writeRegister(.control, gain.rawValue)
    }

    /// Get the gain setting for the measurement.
    /// - Returns:  A gain in enum `Gain`: `.x1`, `.x4`, `.x16`, `.x60`.
    public func getGain() -> Gain {
        var control: UInt8 = 0
        try? readRegister(.control, into: &control)
        return Gain(rawValue: control)!
    }


    /// The gain settings for the measurement.
    public enum Gain: UInt8 {
        /// 1x gain.
        case x1 = 0
        /// 4x gain.
        case x4 = 1
        /// 16x gain.
        case x16 = 2
        /// 60x gain.
        case x60 = 3
    }

    /// Set the integration time of the measurement.
    ///
    /// It will decide the max raw values which equals (256 - time / 2.4) * 1024, and 65535 at most. The longer the time, the more sensitive the sensor at low light level.
    /// - Parameter time: A time in millisecond from 2.4ms to 614.4ms.
    public func setIntegrationTime(_ time: Float) {
        guard time >= 2.4 && time <= 614.4 else {
            print(#function + ": The cycle should be from 1 to 256.")
            return
        }
        integrationTime = time

        try? writeRegister(.aTime, UInt8(256 - time / 2.4))
    }

    /// Set the glass attenuation factor to compensate for the lower light level
    /// at the device if the sensor is placed behind a glass (or other material).
    ///
    /// It is the inverse of the glass transmissivity. By default, it's 1, which
    /// means no glass. It has effect on the lux readings.
    /// - Parameter factor: Glass attenuation factor, 1 by default.
    public func setGlassAttenuation(_ factor: Float) {
        glassAttenuation = factor
    }
}

extension TCS34725 {
    private enum Register: UInt8 {
        case id = 0x12
        case enable = 0x00
        case aTime = 0x01
        case cDataL = 0x14
        case rDataL = 0x16
        case gDataL = 0x18
        case bDataL = 0x1A
        case status = 0x13
        case control = 0x0F
    }

    private struct Enable: OptionSet {
        let rawValue: UInt8

        static let PON = Enable(rawValue: 1)
        static let AEN = Enable(rawValue: 1 << 1)
        static let WEN = Enable(rawValue: 1 << 3)
        static let AIEN = Enable(rawValue: 1 << 4)

        static let powerOn = Enable([.PON])
        static let enable = Enable([.AEN, .PON])
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

    private func writeRegister(_ register: Register, _ data: [UInt8]) throws(Errno) {
        var data = data
        data.insert(register.rawValue | commandBit, at: 0)
        let result = i2c.write(data, to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func getID() -> UInt8 {
        var byte: UInt8 = 0
        try? readRegister(.id, into: &byte)
        return byte
    }

    /// Enable the device for measurement.
    func enable() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)

        try? writeRegister(.enable, byte | Enable.powerOn.rawValue)
        /// 2.4ms warm-up delay after power-on.
        sleep(ms: 3)
        try? writeRegister(.enable, byte | Enable.enable.rawValue)
    }

    /// Disable the sensor and make it enter sleep mode.
    func disable() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)

        try? writeRegister(.enable, byte & ~Enable.enable.rawValue)
    }

    func calculateRBG888(
        r: UInt16, g: UInt16, b: UInt16, c: UInt16
    ) -> UInt32 {
        let red = Float(r)
        let blue = Float(b)
        let green = Float(g)
        let clear = Float(c)

        var redByte = Int(Float.pow(red / clear * 256 / 255, 2.5) * 255)
        var greenByte = Int(Float.pow(green / clear * 256 / 255, 2.5) * 255)
        var blueByte = Int(Float.pow(blue / clear * 256 / 255, 2.5) * 255)

        redByte = min(redByte, 255)
        greenByte = min(greenByte, 255)
        blueByte = min(blueByte, 255)

        return UInt32(redByte) << 16 | UInt32(greenByte) << 8 | UInt32(blueByte)
    }

    /// Calculate color temperature and lux based on the formula on note
    /// (https://ams.com/documents/20143/36005/ColorSensors_AN000166_1-00.pdf/).
    func calculateTempLux(
        r: UInt16, g: UInt16, b: UInt16, c: UInt16
    ) -> (temp: Float, lux: Float) {
        var aTime: UInt8 = 0
        try? readRegister(.aTime, into: &aTime)

        let aTimeMs = (256 - Float(aTime)) * 2.4

        let gain = getGain()
        var aGain: UInt8 {
            switch gain {
            case .x1:
                return 1
            case .x4:
                return 4
            case .x16:
                return 16
            case .x60:
                return 60
            }
        }

        /// Device factor.
        let df: Float = 310.0
        // Coefficients for lux and color temperature calculation.
        let rCoef: Float = 0.136
        let gCoef: Float = 1.0
        let bCoef: Float = -0.444
        let ctCoef: Float = 3810
        let ctOffset: Float = 1391

        /// Saturation check in case that the device is saturated.
        var saturation = min(1024 * (256 - Int(aTime)), 65535)

        if aTimeMs < 150 {
            saturation -= saturation / 4
        }

        if c >= saturation {
            return (0, 0)
        }

        let ir: Float
        if r + g + b > c {
            ir = Float(r + g + b - c) / 2
        } else {
            ir = 0
        }

        var red2 = Float(r) - ir
        let green2 = Float(g) - ir
        let blue2 = Float(b) - ir

        let g1 = rCoef * red2 + gCoef * green2 + bCoef * blue2
        var cpl = (aTimeMs * Float(aGain)) / (glassAttenuation * df)
        if cpl == 0 {
            cpl = 0.001
        }

        let lux = g1 / cpl

        if red2 == 0 {
            red2 = 0.001
        }

        let ct = ctCoef * blue2 / red2 + ctOffset

        return (ct, lux)
    }

}

@_extern(c, "powf")
func powf(_: Float, _ : Float) -> Float

private extension Float {
  @_transparent
  static func pow(_ x: Float, _ y: Float) -> Float {
    guard x >= 0 else { return .nan }
    if x == 0 && y == 0 { return .nan }
    let result = powf(x, y)
    print("powf(\(x), \(y)) result = \(result)")
    return powf(x, y)
  }
}