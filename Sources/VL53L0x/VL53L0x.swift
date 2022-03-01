//=== VL53L0x.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 03/01/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for VL53L0x distance sensor.
///
/// The VL53L0x contains a laser source to emit laser. After the light arrives
/// at the surface of an object, it will be bounced back to the sensor. It then
/// gives you a range reading based on the time to receive the light.
///
/// The sensor provides a 25 degree angle of view, which means the light within
/// that cone could be detected. It can measure 50-1200mm of distance.
final public class VL53L0x {
    private let i2c: I2C
    private let address: UInt8
    private let ioTimeout: Int
    private var readBuffer = [UInt8](repeating: 0, count: 6)
    private var timingBudget: UInt32 = 0
    private var stopVariable: UInt8 = 0
    private var mode: Mode


    /// Initialize the sensor using I2C communication.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   - address: **OPTIONAL** The sensor's address, 0x29 by default.
    ///   - ioTimeout: **OPTIONAL** The timeout for reading from the sensor.
    ///   By default, it's 0 which means there is no timeout, so the sensor
    ///   will continue to read until get the desired reading.
    ///   - mode: **OPTIONAL** The measurement mode: `.single` or `.continuous`.
    public init(_ i2c: I2C, address: UInt8 = 0x29, ioTimeout: Int = 0, mode: Mode = .continuous) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": VL53L0x only supports 100kHz (standard) and 400kHz (fast) I2C speed")
        }

        self.i2c = i2c
        self.address = address
        self.ioTimeout = ioTimeout
        self.mode = mode

        var byte: UInt8 = 0
        try? readRegister(.IDENTIFICATION_MODEL_ID, into: &byte)
        guard byte == 0xEE else {
            fatalError(#function + ": Fail to find VL53L0x at address \(address)")
        }

        dataInit()
        staticInit()
        performRefCalibration()
        if mode == .continuous {
            startContinuous()
        }
    }

    /// Set the maximum time for one measurement.
    ///
    /// A longer timing budget allows for more accurate measurements but
    /// cause slower measuremnt. The default value is about 33ms.
    /// - Parameter budget: Maximum measurement time in microsecond.
    /// It should be bigger than 20ms.
    public func setMeasurementTimingBudget(_ budget: UInt32) {
        guard budget > 20000 else { return }

        var sumBudget = 1320 + OverheadUs.end.rawValue
        let enables = getSequenceStepEnables()
        let timeouts = getSequenceStepTimeouts(enables.preRange)

        if enables.tcc {
            sumBudget += timeouts.msrcDssTccUs + OverheadUs.tcc.rawValue
        }

        if enables.dss {
            sumBudget += 2 * (timeouts.msrcDssTccUs + OverheadUs.dss.rawValue)
        } else if enables.msrc {
            sumBudget += timeouts.msrcDssTccUs + OverheadUs.msrcPreRange.rawValue
        }

        if enables.preRange {
            sumBudget += timeouts.preRangeUs + OverheadUs.msrcPreRange.rawValue
        }

        if enables.finalRange {
            sumBudget += OverheadUs.finalRange.rawValue

            if sumBudget > budget {
                print(#function + ": the timing budget needs to be bigger")
                return
            }

            let finalRangeTimeout = budget - sumBudget
            var finalRangeTimeoutMclks = calTimeoutMclks(finalRangeTimeout, timeouts.finalRangePclks)

            if enables.preRange {
                finalRangeTimeoutMclks += UInt32(timeouts.preRangeMclks)
            }

            let data = encodeTimeout(finalRangeTimeoutMclks)
            try? writeRegister(.FINAL_RANGE_CONFIG_TIMEOUT_MACROP_HI, data)

            timingBudget = budget
        }
    }

    /// Get the measurement timing budget in microseconds.
    /// It is the maximum time for one measurement.
    public func getMeasurementTimingBudget() -> UInt32 {
        var budget: UInt32 = OverheadUs.start.rawValue + OverheadUs.end.rawValue
        let enables = getSequenceStepEnables()
        let timeouts = getSequenceStepTimeouts(enables.preRange)

        if enables.tcc {
            budget += timeouts.msrcDssTccUs + OverheadUs.tcc.rawValue
        }

        if enables.dss {
            budget += 2 * (timeouts.msrcDssTccUs + OverheadUs.dss.rawValue)
        } else if enables.msrc {
            budget += timeouts.msrcDssTccUs + OverheadUs.msrcPreRange.rawValue
        }

        if enables.preRange {
            budget += timeouts.preRangeUs + OverheadUs.msrcPreRange.rawValue
        }

        if enables.finalRange {
            budget += timeouts.finalRangeUs + OverheadUs.finalRange.rawValue
        }

        return budget
    }


    /// Set the return signal rate limit in mega counts per second.
    /// It decides the minimum measurement for a valid reading.
    func setSignalRateLimit(_ limit: Float) {
        guard limit >= 0 && limit <= 511.99 else {
            print(#function + ": signal rate limit should be within 0 - 511.00")
            return
        }

        let value = UInt16(limit * Float(1 << 7))
        let data = [UInt8(value >> 8), UInt8(value & 0xFF)]

        try? writeRegister(.FINAL_RANGE_CONFIG_MIN_COUNT_RATE_RTN_LIMIT, data)
    }

    /// Start continuous ranging measurement. The default mode is continuous
    /// and thus it has been set by default.
    public func startContinuous() {
        try? writeRegister(0x80, 0x01)
        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x00, 0x00)
        try? writeRegister(0x91, stopVariable)
        try? writeRegister(0x00, 0x01)
        try? writeRegister(0xFF, 0x00)
        try? writeRegister(0x80, 0x00)
        try? writeRegister(.SYSRANGE_START, 0x02)

        var byte: UInt8 = 0
        let start = getSystemUptimeInMilliseconds()

        repeat {
            try? readRegister(.SYSRANGE_START, into: &byte)
            if checkTimeout(timeout: ioTimeout, start: start) {
                print(#function + ": Timeout waiting for VL53L0X.")
            }

        } while byte & 0x01 > 0
        mode = .continuous
    }

    /// Stop the continuous measurement. The sensor will enter standby state.
    /// The measurement mode will change to single mode.
    public func stopContinuous() {
        try? writeRegister(.SYSRANGE_START, 0x01)

        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x00, 0x00)
        try? writeRegister(0x91, 0x00)
        try? writeRegister(0x00, 0x01)
        try? writeRegister(0xFF, 0x00)
        mode = .single
    }

    /// Start to measure the range between the object and the sensor.
    /// The sensor should measure range for about 50-1200mm.
    /// So distances exceed that range will return nil.
    /// - Returns: Range in millimeters.
    public func readRange() -> Int? {
        let range: UInt16
        if mode == .single {
            range = readRangeSingle()
        } else {
            range = readRangeContinuous()
        }

        if range > 1300 {
            return nil
        }
        return Int(range)
    }

    /// The measurement modes.
    public enum Mode {
        /// Perform range measurement once. The sensor will enter standy
        /// state automatically until a measurement is set again.
        case single
        /// Perform range measurement continuously. As soon as the measurement
        /// is finished, another one is started without delay.
        case continuous
    }
}







extension VL53L0x {
    enum Register: UInt8 {
        case IDENTIFICATION_MODEL_ID = 0xC0
        case MSRC_CONFIG_CONTROL = 0x60
        case FINAL_RANGE_CONFIG_MIN_COUNT_RATE_RTN_LIMIT = 0x44
        case SYSTEM_SEQUENCE_CONFIG = 0x01
        case GLOBAL_CONFIG_SPAD_ENABLES_REF_0 = 0xB0
        case DYNAMIC_SPAD_REF_EN_START_OFFSET = 0x4F
        case DYNAMIC_SPAD_NUM_REQUESTED_REF_SPAD = 0x4E
        case GLOBAL_CONFIG_REF_EN_START_SELECT = 0xB6
        case SYSTEM_INTERRUPT_CONFIG_GPIO = 0x0A
        case GPIO_HV_MUX_ACTIVE_HIGH = 0x84
        case SYSTEM_INTERRUPT_CLEAR = 0x0B
        case PRE_RANGE_CONFIG_VCSEL_PERIOD = 0x50
        case FINAL_RANGE_CONFIG_VCSEL_PERIOD = 0x70
        case MSRC_CONFIG_TIMEOUT_MACROP = 0x46
        case PRE_RANGE_CONFIG_TIMEOUT_MACROP_HI = 0x51
        case FINAL_RANGE_CONFIG_TIMEOUT_MACROP_HI = 0x71
        case SYSRANGE_START = 0x00
        case RESULT_INTERRUPT_STATUS = 0x13
        case RESULT_RANGE_STATUS = 0x14
    }

    enum OverheadUs: UInt32 {
        case start = 1910
        case end = 960
        case msrcPreRange = 660
        case tcc = 590
        case dss = 690
        case finalRange = 550
    }

    enum VcselPeriodType {
        case preRange
        case finalRange
    }

    func writeRegister(_ reg: UInt8, _ value: UInt8) throws {
        let result = i2c.write([reg, value], to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func writeRegister(_ reg: Register, _ value: UInt8) throws {
        let result = i2c.write([reg.rawValue, value], to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func writeRegister(_ reg: Register, _ data: [UInt8]) throws {
        var data = data
        data.insert(reg.rawValue, at: 0)
        let result = i2c.write(data, to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func readRegister(
        _ reg: Register, into byte: inout UInt8
    ) throws {
        var result = i2c.write(reg.rawValue, to: address)
        if case .failure(let err) = result {
            throw err
        }

        result = i2c.read(into: &byte, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func readRegister(
        _ reg: Register, into buffer: inout [UInt8], count: Int
    ) throws {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        var result = i2c.write(reg.rawValue, to: address)
        if case .failure(let err) = result {
            throw err
        }

        result = i2c.read(into: &buffer, count: count, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func readRegister(
        _ reg: UInt8, into buffer: inout [UInt8], count: Int
    ) throws {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        var result = i2c.write(reg, to: address)
        if case .failure(let err) = result {
            throw err
        }

        result = i2c.read(into: &buffer, count: count, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func readRegister(
        _ reg: UInt8, into byte: inout UInt8
    ) throws {
        var result = i2c.write(reg, to: address)
        if case .failure(let err) = result {
            throw err
        }

        result = i2c.read(into: &byte, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func dataInit() {
        /// Set I2C standard mode.
        try? writeRegister(0x88, 0x00)

        try? writeRegister(0x80, 0x01)
        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x00, 0x00)

        try? readRegister(0x91, into: &stopVariable)

        try? writeRegister(0x00, 0x01)
        try? writeRegister(0xFF, 0x00)
        try? writeRegister(0x80, 0x00)

        /// MSRC (Minimum Signal Rate Check).
        /// Disable SIGNAL_RATE_MSRC (bit 1) and SIGNAL_RATE_PRE_RANGE (bit 4) limit checks
        var byte: UInt8 = 0
        try? readRegister(.MSRC_CONFIG_CONTROL, into: &byte)
        try? writeRegister(.MSRC_CONFIG_CONTROL, byte | 0x12)

        setSignalRateLimit(0.25)

        try? writeRegister(.SYSTEM_SEQUENCE_CONFIG, 0xFF)
    }

    func staticInit() {
        setSpad()
        loadTuningSetting()
        setGpioConfig()
        timingBudget = getMeasurementTimingBudget()

        // Disable msrc (Minimum Signal Rate Check) and tcc (Target Centre Check).
        try? writeRegister(.SYSTEM_SEQUENCE_CONFIG, 0xE8)

        setMeasurementTimingBudget(timingBudget)
    }

    func performRefCalibration() {
        // Perform vhv calibration.
        try? writeRegister(.SYSTEM_SEQUENCE_CONFIG, 0x01)
        performSingleRefCalibration(0x40)

        // Perform phase calibration.
        try? writeRegister(.SYSTEM_SEQUENCE_CONFIG, 0x02)
        performSingleRefCalibration(0x00)

        try? writeRegister(.SYSTEM_SEQUENCE_CONFIG, 0xE8)
    }

    func performSingleRefCalibration(_ vhvInitByte: UInt8) {
        try? writeRegister(.SYSRANGE_START, 0x01 | vhvInitByte)
        let start = getSystemUptimeInMilliseconds()

        var byte: UInt8 = 0
        repeat {
            try? readRegister(.RESULT_INTERRUPT_STATUS, into: &byte)

            if checkTimeout(timeout: ioTimeout, start: start) {
                print(#function + ": Timeout waiting for VL53L0X.")
            }
        } while byte & 0x07 == 0

        try? writeRegister(.SYSTEM_INTERRUPT_CLEAR, 0x01)
        try? writeRegister(.SYSRANGE_START, 0x00)
    }

    func calTimeoutUs(_ timeoutMclkd: UInt16, _ vcselPclks: UInt8) -> UInt32 {
        let macroPeriodns = (2304 * UInt32(vcselPclks) * 1655 + 500) / 1000
        return (UInt32(timeoutMclkd) * macroPeriodns + 500) / 1000
    }

    func calTimeoutMclks(_ timeoutUs: UInt32, _ vcselPclks: UInt8) -> UInt32 {
        let macroPeriodns = (2304 * UInt32(vcselPclks) * 1655 + 500) / 1000
        return (timeoutUs * 1000 + macroPeriodns / 2) / macroPeriodns
    }


    func setGpioConfig() {
        try? writeRegister(.SYSTEM_INTERRUPT_CONFIG_GPIO, 0x04)
        var byte: UInt8 = 0
        try? readRegister(.GPIO_HV_MUX_ACTIVE_HIGH, into: &byte)
        try? writeRegister(.GPIO_HV_MUX_ACTIVE_HIGH, byte & ~0x10)
        try? writeRegister(.SYSTEM_INTERRUPT_CLEAR, 0x01)
    }

    func loadTuningSetting() {
        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x00, 0x00)

        try? writeRegister(0xFF, 0x00)
        try? writeRegister(0x09, 0x00)
        try? writeRegister(0x10, 0x00)
        try? writeRegister(0x11, 0x00)

        try? writeRegister(0x24, 0x01)
        try? writeRegister(0x25, 0xFF)
        try? writeRegister(0x75, 0x00)

        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x4E, 0x2C)
        try? writeRegister(0x48, 0x00)
        try? writeRegister(0x30, 0x20)

        try? writeRegister(0xFF, 0x00)
        try? writeRegister(0x30, 0x09)
        try? writeRegister(0x54, 0x00)
        try? writeRegister(0x31, 0x04)
        try? writeRegister(0x32, 0x03)
        try? writeRegister(0x40, 0x83)
        try? writeRegister(0x46, 0x25)
        try? writeRegister(0x60, 0x00)
        try? writeRegister(0x27, 0x00)
        try? writeRegister(0x50, 0x06)
        try? writeRegister(0x51, 0x00)
        try? writeRegister(0x52, 0x96)
        try? writeRegister(0x56, 0x08)
        try? writeRegister(0x57, 0x30)
        try? writeRegister(0x61, 0x00)
        try? writeRegister(0x62, 0x00)
        try? writeRegister(0x64, 0x00)
        try? writeRegister(0x65, 0x00)
        try? writeRegister(0x66, 0xA0)

        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x22, 0x32)
        try? writeRegister(0x47, 0x14)
        try? writeRegister(0x49, 0xFF)
        try? writeRegister(0x4A, 0x00)

        try? writeRegister(0xFF, 0x00)
        try? writeRegister(0x7A, 0x0A)
        try? writeRegister(0x7B, 0x00)
        try? writeRegister(0x78, 0x21)

        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x23, 0x34)
        try? writeRegister(0x42, 0x00)
        try? writeRegister(0x44, 0xFF)
        try? writeRegister(0x45, 0x26)
        try? writeRegister(0x46, 0x05)
        try? writeRegister(0x40, 0x40)
        try? writeRegister(0x0E, 0x06)
        try? writeRegister(0x20, 0x1A)
        try? writeRegister(0x43, 0x40)

        try? writeRegister(0xFF, 0x00)
        try? writeRegister(0x34, 0x03)
        try? writeRegister(0x35, 0x44)

        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x31, 0x04)
        try? writeRegister(0x4B, 0x09)
        try? writeRegister(0x4C, 0x05)
        try? writeRegister(0x4D, 0x04)

        try? writeRegister(0xFF, 0x00)
        try? writeRegister(0x44, 0x00)
        try? writeRegister(0x45, 0x20)
        try? writeRegister(0x47, 0x08)
        try? writeRegister(0x48, 0x28)
        try? writeRegister(0x67, 0x00)
        try? writeRegister(0x70, 0x04)
        try? writeRegister(0x71, 0x01)
        try? writeRegister(0x72, 0xFE)
        try? writeRegister(0x76, 0x00)
        try? writeRegister(0x77, 0x00)

        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x0D, 0x01)

        try? writeRegister(0xFF, 0x00)
        try? writeRegister(0x80, 0x01)
        try? writeRegister(0x01, 0xF8)

        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x8E, 0x01)
        try? writeRegister(0x00, 0x01)
        try? writeRegister(0xFF, 0x00)
        try? writeRegister(0x80, 0x00)
    }

    func setSpad() {
        let spadInfo = getSpadInfo()
        guard spadInfo != nil else {
            print(#function + ": Failt to get spad info")
            return
        }

        try? readRegister(.GLOBAL_CONFIG_SPAD_ENABLES_REF_0, into: &readBuffer, count: 6)

        try? writeRegister(0xFF, 0x01)
        try? writeRegister(.DYNAMIC_SPAD_REF_EN_START_OFFSET, 0x00)
        try? writeRegister(.DYNAMIC_SPAD_NUM_REQUESTED_REF_SPAD, 0x2C)
        try? writeRegister(0xFF, 0x00)
        try? writeRegister(.GLOBAL_CONFIG_REF_EN_START_SELECT, 0xB4)

        var firstSpad = 0

        if spadInfo!.1 == true {
            firstSpad = 12
        }

        var spadEnabled = 0

        for i in 0..<48 {
            if i < firstSpad || spadEnabled == spadInfo!.0 {
                readBuffer[i / 8] &= ~(1 << (i % 8))
            } else if (readBuffer[i / 8] >> (i % 8)) & 0x01 != 0 {
                spadEnabled += 1
            }
        }

        try? writeRegister(.GLOBAL_CONFIG_SPAD_ENABLES_REF_0, readBuffer)
    }



    /// Get reference SPAD (single photon avalanche diode) count and type used
    /// as receiver.
    func getSpadInfo() -> (UInt8, Bool)? {
        try? writeRegister(0x80, 0x01)
        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x00, 0x00)

        try? writeRegister(0xFF, 0x06)

        var byte: UInt8 = 0
        try? readRegister(0x83, into: &byte)
        try? writeRegister(0x83, byte | 0x04)

        try? writeRegister(0xFF, 0x07)
        try? writeRegister(0x81, 0x01)

        try? writeRegister(0x80, 0x01)

        try? writeRegister(0x94, 0x6b)
        try? writeRegister(0x83, 0x00)

        let start = getSystemUptimeInMilliseconds()

        repeat {
            try? readRegister(0x83, into: &byte)
            if checkTimeout(timeout: ioTimeout, start: start) {
                return nil
            }
        } while byte == 0

        try? writeRegister(0x83, 0x01)
        try? readRegister(0x92, into: &byte)
        let count = byte & 0x7F
        let isAperture = (byte >> 7) & 0x01 == 0x01


        try? writeRegister(0x81, 0x00)
        try? writeRegister(0xFF, 0x06)

        try? readRegister(0x83, into: &byte)
        try? writeRegister(0x83, byte & (~0x04))

        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x00, 0x01)

        try? writeRegister(0xFF, 0x00)
        try? writeRegister(0x80, 0x00)

        return (count, isAperture)
    }

    func decodeTimeout(msb: UInt8, lsb: UInt8) -> UInt16 {
        return (UInt16(lsb) << msb) + 1
    }

    func encodeTimeout(_ timeout: UInt32) -> [UInt8] {
        var lsb: UInt32 = 0
        var msb: UInt16 = 0

        if (timeout > 0) {
            lsb = timeout - 1

            while (lsb & 0xFFFFFF00) > 0 {
                lsb = lsb >> 1
                msb += 1
            }
        }

        return [UInt8(msb), UInt8(lsb)]
    }

    func getSequenceStepEnables() -> (tcc: Bool, dss: Bool, msrc: Bool, preRange: Bool, finalRange: Bool){
        var byte: UInt8 = 0
        try? readRegister(.SYSTEM_SEQUENCE_CONFIG, into: &byte)
        let tcc          = (byte >> 4) & 0x1 == 0x01
        let dss          = (byte >> 3) & 0x1 == 0x01
        let msrc         = (byte >> 2) & 0x1 == 0x01
        let preRange    = (byte >> 6) & 0x1 == 0x01
        let finalRange  = (byte >> 7) & 0x1 == 0x01
        return (tcc: tcc, dss: dss, msrc: msrc, preRange: preRange, finalRange: finalRange)
    }

    /// Get the VCSEL pulse period in PCLKs with the specified period type.
    func getVcselPulsePeriod(_ type: VcselPeriodType) -> UInt8 {
        var byte: UInt8 = 0
        if type == .preRange {
            try? readRegister(.PRE_RANGE_CONFIG_VCSEL_PERIOD, into: &byte)
        } else {
            try? readRegister(.FINAL_RANGE_CONFIG_VCSEL_PERIOD, into: &byte)
        }

        return (byte + 1) << 1
    }


    func getSequenceStepTimeouts(_ preRange: Bool) -> (msrcDssTccUs: UInt32, preRangeMclks: UInt16, preRangeUs: UInt32, finalRangePclks: UInt8, finalRangeUs: UInt32) {
        let preRangePclks = getVcselPulsePeriod(.preRange)

        var byte: UInt8 = 0
        try? readRegister(.MSRC_CONFIG_TIMEOUT_MACROP, into: &byte)
        let msrcDssTccMclks = UInt16(byte) + 1
        let msrcDssTccUs = calTimeoutUs(msrcDssTccMclks, preRangePclks)

        try? readRegister(.PRE_RANGE_CONFIG_TIMEOUT_MACROP_HI, into: &readBuffer, count: 2)
        let preRangeMclks = decodeTimeout(msb: readBuffer[0], lsb: readBuffer[1])

        let preRangeUs = calTimeoutUs(preRangeMclks, preRangePclks)

        let finalRangePclks = getVcselPulsePeriod(.finalRange)

        try? readRegister(.FINAL_RANGE_CONFIG_TIMEOUT_MACROP_HI, into: &readBuffer, count: 2)
        var finalRangeMclks = decodeTimeout(msb: readBuffer[0], lsb: readBuffer[1])

        if preRange {
            finalRangeMclks -= preRangeMclks
        }

        let finalRangeUs = calTimeoutUs(finalRangeMclks, finalRangePclks)

        return (msrcDssTccUs: msrcDssTccUs, preRangeMclks: preRangeMclks, preRangeUs: preRangeUs, finalRangePclks: finalRangePclks, finalRangeUs: finalRangeUs)
    }


    func readRangeContinuous() -> UInt16 {
        let start = getSystemUptimeInMilliseconds()
        var byte: UInt8 = 0

        repeat {
            try? readRegister(.RESULT_INTERRUPT_STATUS, into: &byte)

            if checkTimeout(timeout: ioTimeout, start: start) {
                print(#function + ": Timeout waiting for VL53L0X.")
                return 0
            }
        } while byte & 0x07 == 0

        try? readRegister(Register.RESULT_RANGE_STATUS.rawValue + 10, into: &readBuffer, count: 2)
        try? writeRegister(.SYSTEM_INTERRUPT_CLEAR, 0x01)
        return UInt16(readBuffer[0]) << 8 | UInt16(readBuffer[1])
    }

    func readRangeSingle() -> UInt16 {
        try? writeRegister(0x80, 0x01)
        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x00, 0x00)
        try? writeRegister(0x91, stopVariable)
        try? writeRegister(0x00, 0x01)
        try? writeRegister(0xFF, 0x00)
        try? writeRegister(0x80, 0x00)
        try? writeRegister(.SYSRANGE_START, 0x01)

        let start = getSystemUptimeInMilliseconds()

        var byte: UInt8 = 0

        repeat {
            try? readRegister(.SYSRANGE_START, into: &byte)

            if checkTimeout(timeout: ioTimeout, start: start) {
                print(#function + ": Timeout waiting for VL53L0X.")
                return 0
            }
        } while byte & 0x01 > 0

        return readRangeContinuous()
    }

    func checkTimeout(timeout: Int, start: Int64) -> Bool {
        return ioTimeout > 0 && getSystemUptimeInMilliseconds() - start >= ioTimeout
    }


}
