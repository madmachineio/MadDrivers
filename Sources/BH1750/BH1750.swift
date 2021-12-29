//=== BH1750.swift --------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 10/26/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for the BH1750 light sensor
/// used to measure light intensity.
///
/// The sensor communicates with your board via an I2C bus.
/// It provides 16-bit resolution to sense the amount of ambiant light.
/// The light will be 0 to 65535 lux (lx).
final public class BH1750 {
    
    private let i2c: I2C
    private let address: UInt8
    
    private let mode: Mode
    private var resolution: Resolution

    private var measurementTime: Int {
        switch resolution {
        case .high, .middle:
            return 140
        case .low:
            return 24
        }
    }

    private var unit: Float {
        switch resolution {
        case .high:
            return 0.5
        case .middle, .low:
            return 1.0
        }
    }

    private var readBuffer = [UInt8](repeating: 0, count: 2)

    /// Initialize the light sensor.
    ///
    /// The sensor provides two options for the address. If the pin ADDR is
    /// low voltage, the address is 0x23. If it is high voltage,
    /// the address is 0x5C.
    /// - Parameters:
    ///   - i2c: **REQUIRED** An I2C pin for the communication. The maximum
    ///   I2C speed is 400KHz.
    ///   - address: **OPTIONAL** The sensor's address. 0x23 by default.
    ///   - mode: **OPTIONAL** Whether the sensor measures once or continuously.
    ///     `.continuous` by default.
    ///   - resolution: **OPTIONAL** The resolution for the measurement.
    ///     `.middle` by default.
    public init(_ i2c: I2C, address: UInt8 = 0x23,
                mode: Mode = .continuous, resolution: Resolution = .middle) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": BH1750 only supports 100kbps and 400kbps I2C speed")
        }

        self.i2c = i2c
        self.address = address
        self.mode = mode
        self.resolution = resolution

        reset()
        setResolution(resolution)
    }
    
    /// Read the ambient light and represent it in lux.
    /// - Returns: A float representing the light amount in lux.
    public func readLux() -> Float {
        switch mode {
        case .continuous:
            /// In this mode, the sensor measures the light continuously,
            /// so you can read directly.
            try? readValue(into: &readBuffer, count: 2)
        case .oneTime:
            /// In this mode, every time the sensor finishes the reading,
            /// the sensor will move to power down mode.
            /// You need to resend the command for a new reading.
            let configValue = mode.rawValue | resolution.rawValue
            try? writeValue(configValue)
            sleep(ms: measurementTime)
            try? readValue(into: &readBuffer, count: 2)
        }

        let rawValue =  UInt16(readBuffer[0]) << 8 | UInt16(readBuffer[1])
        return Float(rawValue) * unit / 1.2
    }

    /// Set resolution for the brightness measurement.
    /// - Parameter resolution: The resolution: `.high`, `.middle` or `.low`.
    public func setResolution(_ resolution: Resolution) {
        self.resolution = resolution
        try? writeValue(mode.rawValue | resolution.rawValue)
        sleep(ms: measurementTime)
    }

    /// It decides if the sensor will measure the light all the time or once.
    public enum Mode: UInt8 {
        /// The sensor will read the ambient light continuously.
        case continuous = 0b0001_0000
        /// The sensor will read once and move to powered down mode
        /// until the next reading.
        case oneTime = 0b0010_0000
    }

    /// It decides the precision of the measurement. `.middle` by default.
    public enum Resolution: UInt8 {
        /// Start measurement at 0.5lx resolution.
        case high = 0b0001
        /// Start measurement at 1lx resolution.
        case middle = 0b0000
        /// Start measurement at 4lx resolution.
        case low = 0b0011
    }
}

extension BH1750 {
    private enum Command: UInt8 {
        case powerOn = 0b0001
        case reset = 0b0111
    }

    private func reset() {
        try? writeValue(Command.powerOn.rawValue)
        try? writeValue(Command.reset.rawValue)
    }

    private func writeValue(_ value: UInt8) throws {
        let result = i2c.write(value, to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func readValue(into buffer: inout [UInt8], count: Int) throws {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        let result = i2c.read(into: &buffer, count: count, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }
}

