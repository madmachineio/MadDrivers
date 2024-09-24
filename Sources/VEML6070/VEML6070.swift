//=== VEML6070.swift ------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 03/11/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for the VEML6070 ultraviolet (UV) light sensor.
///
/// It uses I2C interface to communicate with your board. It detects the UV light
/// intensity and changes it into digital data. This sensor doesn't give you
/// the UV index, but you can get the radiation level based on its 16-bit raw
/// readings.
///
final public class VEML6070 {
    private let i2c: I2C
    private var integrationTime: IntegrationTime = .t1
    private var ack: UInt8 = 0
    private var ackThreshold: UInt8 = 0

    /// Initialize the sensor using I2C communication with all other
    /// configuration set to default.
    ///
    /// The sensor has several device addresses for a specific uages during
    /// communication, so they are not passed in as parameter like other drivers.
    /// The default integration time is `.t1`.
    /// - Parameter i2c: **REQUIRED** The I2C interface that the sensor connects to.
    public init(_ i2c: I2C) {
        self.i2c = i2c

        clearAck()
        setIntegrationTime(integrationTime)
    }

    /// Read UV light intensity from the sensor.
    /// This is a raw data from the sensor and needs to be used with the method
    /// `getUVLevel` to get UV radiation level.
    /// - Returns: A UInt16 raw reading.
    public func readUVRaw() -> UInt16 {
        var msb: UInt8 = 0
        i2c.read(into: &msb, from: Address.msb.rawValue)

        var lsb: UInt8 = 0
        i2c.read(into: &lsb, from: Address.cmdLsb.rawValue)

        return UInt16(msb) << 8 | UInt16(lsb)
    }


    /// Get UV level based on the light intensity.
    ///
    /// The sensor doesn't provide a UV index directly but tells the UV level.
    /// The relation of the UV index and level is as follows:
    /// low: 0-2, moderate: 3-5, high: 6-7, very high: 8-10, extreme: >=11.
    /// - Parameter rawUV: UV light raw value read from the sensor.
    /// - Returns: A UV index level: `.low`, `.moderate`, `.high`, `.veryHigh`
    /// or `.extreme`.
    public func getUVLevel(_ rawUV: UInt16) -> UVLevel {
        var uv: UInt16 {
            switch integrationTime {
            case .tHalf:
                return rawUV * 2
            case .t1:
                return rawUV
            case .t2:
                return rawUV / 2
            case .t4:
                return rawUV / 4
            }
        }

        if uv <= 560 {
            return .low
        } else if uv <= 1120 {
            return .moderate
        } else if uv <= 1494 {
            return .high
        } else if uv <= 2054 {
            return .veryHigh
        } else {
            return .extreme
        }
    }

    /// Set interrupt for the sensor. It it's enabled, the sensor will send a
    /// acnkowledge signal when the UV reading exceeds the threshold.
    /// - Parameters:
    ///   - enable: Whether to enable the interrupt.
    ///   - threshold: The threshold for acknowledge signal.
    ///   true for 145 and false for 102.
    public func setInterrupt(enable: Bool, threshold: Bool) {
        ack = enable ? 1 : 0
        ackThreshold = threshold ? 1 : 0
        let command = ack << 5 | ackThreshold << 4 | integrationTime.rawValue << 2 | 0x02
        try? writeCommand(command)
    }


    /// Set the integration time for the measurement. The time is longer,
    /// the reading will be more accurate.
    /// - Parameter time: A time option in `IntegrationTime`.
    public func setIntegrationTime(_ time: IntegrationTime) {
        integrationTime = time
        let command = ack << 5 | ackThreshold << 4 | integrationTime.rawValue << 2 | 0x02
        try? writeCommand(command)
    }

    /// Make the sensor enter to shutdown mode.
    /// In this mode, the power consumption will be less than 1 μA.
    public func sleep() {
        try? writeCommand(0x03)
    }

    /// Wake up the sensor from shutdown mode.
    public func wake() {
        let command = ack << 5 | ackThreshold << 4 | integrationTime.rawValue << 2 | 0x02
        try? writeCommand(command)
    }

    /// UV levels that tells the UV radiation.
    public enum UVLevel {
        /// The UV index is 0-2.
        case low
        /// The UV index is 3-5.
        case moderate
        /// The UV index is 6-7.
        case high
        /// The UV index is 8-10.
        case veryHigh
        /// The UV index is >=11.
        case extreme
    }

    /// Integration time used to measure UV light.
    ///
    /// The time depends on the resistor RSET connected to the sensor according
    /// to the datasheet.
    public enum IntegrationTime: UInt8 {
        /// 62.5ms if RSET value is 300kΩ.
        case tHalf = 0
        /// 125ms if RSET value is 300kΩ.
        case t1 = 1
        /// 250ms if RSET value is 300kΩ.
        case t2 = 2
        /// 500ms if RSET value is 300kΩ.
        case t4 = 3
    }
}

extension VEML6070 {
    private enum Address: UInt8 {
        case cmdLsb = 0x38
        case msb = 0x39
        case ara = 0x0C
    }

    private func writeCommand(_ command: UInt8) throws(Errno) {
        let result = i2c.write(command, to: Address.cmdLsb.rawValue)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func clearAck() {
        var byte: UInt8 = 0
        i2c.read(into: &byte, from: Address.ara.rawValue)
    }


}
