//=== MPR121.swift -----------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 02/28/2023
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for MPR121 Capacitive Touch Sensor.
///
/// MPR121 provides 12 touch pads that are connected to its internal electrodes.
/// When a touch pad is touched, the capacitance between the electrode and
/// the conductive object (such as fingers) changes, which MPR121 detects.
/// Then it compares this data with a baseline value to determine
/// if a pad has been touched.
///
/// MPR121 supports I2C communication. It provides 4 configurable addresses,
/// which means that up to 4 MPR121 sensors can be used together to detect up to
/// 48 touch pads in total.
///
/// The addresses are selected by ADDR pin connections.
/// If you connect the ADDR pin to the GND, 3V3, SDA or SCL lines,
/// I2C addresses are 0x5A, 0x5B, 0x5C and 0x5D respectively.
final public class MPR121 {
    private let i2c: I2C
    private let address: UInt8

    /// Initialize the sensor using I2C communication.
    ///
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   The maximum supporting I2C speed is 400KHz.
    ///   - address: **OPTIONAL** The device address of the sensor. 0x5A by default.
    ///   If you connect the ADDR pin to the GND, 3V3, SDA or SCL lines,
    ///   I2C addresses are 0x5A, 0x5B, 0x5C and 0x5D respectively.
    public init(_ i2c: I2C, address: UInt8 = 0x5A) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": MPR121 only supports 100kHz (standard) and 400kHz (fast) I2C speed")
        }
        
        self.i2c = i2c
        self.address = address

        try? reset()
    }


    /// Check if a certain pin is touched.
    /// - Parameter pin: Pin number from 0 to 11.
    /// - Returns: `true` if the pin is touched; or else, `false`.
    public func isTouched(pin: Int) -> Bool {
        guard pin < 12 && pin >= 0 else {
            print("The pin number isn't whithin 0-11")
            return false
        }

        return (readTouchStatus() & (1 << pin)) > 0
    }

    /// Set the touch threshold for a specified pin.
    ///
    /// In a typical touch detection application, threshold is typically in the range 0x04-0x10.
    /// The touch threshold is several counts larger than the release threshold.
    ///
    /// Touch condition: Baseline - Electrode filtered data > Touch threshold.
    /// The baseline is tracked automatically based on the background capacitance variation.
    /// - Parameters:
    ///   - pin: Pin number from 0 to 11.
    ///   - threshold: The threshold is in range of 0~0xFF.
    public func setTouchThreshold(pin: Int, _ threshold: UInt8) {
        guard pin < 12 && pin >= 0 else { return }
        try? writeRegister(Register.E0TTH, offset: UInt8(2 * pin), threshold)
    }

    /// Set the release threshold for a specified pin.
    ///
    /// In a typical touch detection application, threshold is typically in the range 0x04-0x10.
    /// The touch threshold is several counts larger than the release threshold.
    ///
    /// Release condition: Baseline - Electrode filtered data < Release threshold.
    /// The baseline is tracked automatically based on the background capacitance variation.
    /// - Parameters:
    ///   - pin: Pin number from 0 to 11.
    ///   - threshold: The threshold is in range of 0~0xFF.
    public func setReleaseThreshold(pin: Int, _ threshold: UInt8) {
        guard pin < 12 && pin >= 0 else { return }
        try? writeRegister(Register.E0RTH, offset: UInt8(2 * pin), threshold)
    }

    /// Get the filtered electrode data on a specified pin.
    ///
    /// Touch and release are detected by comparing the filtered data to the baseline.
    /// - Parameter pin: Pin number from 0 to 11.
    /// - Returns: 10-bit filtered data value.
    public func getRawValue(pin: Int) -> UInt16 {
        guard pin < 12 && pin >= 0 else {
            print("The pin number isn't whithin 0-11")
            return 0
        }

        var buffer: [UInt8] = [0, 0]
        try? readRegister(.EFD0LB, offset: UInt8(2 * pin), into: &buffer)
        return UInt16(buffer[0]) | UInt16(buffer[1]) << 8
    }

    /// Get the capacitance baseline value on a specified pin.
    ///
    /// The baseline is tracked automatically based on the background capacitance variation.
    /// Touch and release are detected by comparing the electrode filtered data to the baseline.
    /// - Parameter pin: Pin number from 0 to 11.
    /// - Returns: 10-bit baseline value.
    public func getBaseline(pin: Int) -> UInt16 {
        guard pin < 12 && pin >= 0 else {
            print("The pin number isn't whithin 0-11")
            return 0
        }

        var baseline: UInt8 = 0
        try? readRegister(Register.E0BV, offset: UInt8(pin), into: &baseline)
        return UInt16(baseline) << 2
    }
}


extension MPR121 {
    enum Register: UInt8 {
        case TOUCHSTATUS = 0x00
        case EFD0LB = 0x04
        case E0BV = 0x1E
        case MHDR = 0x2B
        case NHDR = 0x2C
        case NCLR = 0x2D
        case FDLR = 0x2E
        case MHDF = 0x2F
        case NHDF = 0x30
        case NCLF = 0x31
        case FDLF = 0x32
        case NHDT = 0x33
        case NCLT = 0x34
        case FDLT = 0x35
        case E0TTH = 0x41
        case E0RTH = 0x42
        case Debounce = 0x5B
        case CDCCONFIG = 0x5C
        case CDTCONFIG = 0x5D
        case ECR = 0x5E
        case SRST = 0x80
    }

    private func i2cWriteRegister(_ register: UInt8, _ value: UInt8) throws {
        let result = i2c.write([register, value], to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func writeRegister(_ register: Register, offset: UInt8 = 0, _ value: UInt8) throws {
        // Most registers can be written when the sensor is in Stop Mode.
        let stopRequired: Bool = !(register.rawValue == Register.ECR.rawValue || (register.rawValue >= 0x73 && register.rawValue <= 0x7A))

        // Set the sensor to Stop Mode to write specified register.
        if stopRequired {
            try i2cWriteRegister(Register.ECR.rawValue, 0x00)
        }

        try i2cWriteRegister(register.rawValue + offset, value)

        // Set the sensor to Run Mode.
        if stopRequired {
            try i2cWriteRegister(Register.ECR.rawValue, 0x8F)
        }
    }

    private func readRegister(_ register: Register, offset: UInt8 = 0, into buffer: inout [UInt8]) throws {
        for i in buffer.indices {
            buffer[i] = 0
        }
        
        let result = i2c.writeRead(register.rawValue + offset, into: &buffer, address: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func readRegister(_ register: Register, offset: UInt8 = 0, into byte: inout UInt8) throws {
        let result = i2c.writeRead(register.rawValue + offset, into: &byte, address: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func reset() throws {
        try writeRegister(.SRST, 0x63)
        sleep(ms: 1)

        // The ECR reset default value is 0x00.
        try writeRegister(.ECR, 0x00)

        var configValue: UInt8 = 0
        try readRegister(.CDTCONFIG, into: &configValue)

        if configValue != 0x24 {
            fatalError(#function + ": Fail to find MPR121 with expected configurations.")
        }

        // Set touch and release threshold
        for i in 0..<12 {
            try writeRegister(Register.E0TTH, offset: UInt8(2 * i) , 12)
            try writeRegister(Register.E0RTH, offset: UInt8(2 * i), 6)
        }

        // Set electrode baseline values.
        try writeRegister(.MHDR, 0x01)
        try writeRegister(.NHDR, 0x01)
        try writeRegister(.NCLR, 0x0E)
        try writeRegister(.FDLR, 0x00)
        try writeRegister(.MHDF, 0x01)
        try writeRegister(.NHDF, 0x05)
        try writeRegister(.NCLF, 0x01)
        try writeRegister(.FDLF, 0x00)
        try writeRegister(.NHDT, 0x00)
        try writeRegister(.NCLT, 0x00)
        try writeRegister(.FDLT, 0x00)

        try writeRegister(.Debounce, 0)
        // Sets the charge discharge current to 16 μA.
        try writeRegister(.CDCCONFIG, 0x10)
        // Set the charge time applied to electrode to 0.5 μs,
        // the number of samples to 4 and the period between samples to 1 ms.
        try writeRegister(.CDTCONFIG, 0x20)

        // Enable all electrode detection.
        // Enable baseline tracking. Initial baseline value is loaded with the 5 high bits of the first 10-bit electrode data value.
        try writeRegister(.ECR, 0x8F)
    }

    func readTouchStatus() -> UInt16 {
        var buffer: [UInt8] = [0, 0]
        try? readRegister(.TOUCHSTATUS, into: &buffer)
        return UInt16(buffer[0]) | UInt16(buffer[1]) << 8
    }
}
