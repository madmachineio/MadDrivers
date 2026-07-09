//=== EPD1in54G.swift -----------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Andy Liu
// Created: 07/07/2026
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO


/// This is the library for Waveshare 1.54inch four-color e-Paper (G) module.
///
/// The screen resolution is 200x200. It supports four colors and stores
/// pixels as 2-bit values: black, white, yellow, and red. Four pixels are
/// packed into one byte, with the leftmost pixel stored in bits 7...6.
public final class EPD1in54G {

    public static let width = 200
    public static let height = 200
    public static let bytesPerRow = width / 4
    public static let bufferSize = bytesPerRow * height

    private let normalInitConfigs: [(address: Command, data: [UInt8]?)] = [
        (.panelSettingExtra, [0x78]),
        (.panelSetting, [0x0F, 0x29]),
        (.boosterSoftStart, [0x0D, 0x12, 0x30, 0x20, 0x19, 0x2A, 0x22]),
        (.vcomAndDataInterval, [0x37]),
        (.resolutionSetting, [0x00, 0xC8, 0x00, 0xC8]),
        (.commandE9, [0x01]),
        (.pllControl, [0x08])
    ]

    private let fastUpdateConfigs: [(address: Command, data: [UInt8]?)] = [
        (.temperatureInputSelection, [0x02]),
        (.manualTemperature, [0x5D]),
        (.fastModeControl, [0x00])
    ]

    let spi: SPI
    let cs, dc, rst: DigitalOut
    let busy: DigitalIn
    let pwr: DigitalOut?

    /// Initialize all the necessary pins and optionally initialize the panel.
    /// - Parameters:
    ///   - spi: **REQUIRED** SPI interface. Use SPI mode 0, MSB first.
    ///   - cs: **REQUIRED** The digital output pin used for chip select.
    ///   - dc: **REQUIRED** The digital output pin used for data or command.
    ///   - rst: **REQUIRED** The digital output pin used to reset the screen.
    ///   - busy: **REQUIRED** The digital input pin used to read busy state.
    ///   - pwr: **OPTIONAL** The digital output pin used to power the module.
    ///   - autoInitialize: **OPTIONAL** Initialize the panel immediately.
    public init(spi: SPI, cs: DigitalOut, dc: DigitalOut, rst: DigitalOut,
                busy: DigitalIn, pwr: DigitalOut? = nil,
                autoInitialize: Bool = true) {
        self.spi = spi
        self.cs = cs
        self.dc = dc
        self.rst = rst
        self.busy = busy
        self.pwr = pwr

        cs.high()
        dc.high()
        pwr?.high()

        if autoInitialize {
            initializeForFullUpdate()
        }
    }

    /// Initialize the e-Paper panel for the standard full update sequence.
    /// - Returns: `true` if all busy waits completed before timeout.
    @discardableResult
    public func initializeForFullUpdate(timeout: Float = 20.0) -> Bool {
        pwr?.high()
        reset()
        writeConfigs(normalInitConfigs)
        writeCommand(.powerOn)
        return waitUntilBusyHigh(timeout: timeout)
    }

    /// Initialize the e-Paper panel for the fast full update sequence.
    ///
    /// This still performs a full-screen refresh. The added commands force a
    /// temperature-related mode used by the vendor demo to shorten the following
    /// display refresh time, not the initialization time.
    /// - Returns: `true` if all busy waits completed before timeout.
    @discardableResult
    public func initializeForFastUpdate(timeout: Float = 20.0) -> Bool {
        guard initializeForFullUpdate(timeout: timeout) else { return false }
        writeConfigs(fastUpdateConfigs)
        return waitUntilBusyHigh(timeout: timeout)
    }

    /// Initialize the panel for the standard full update sequence.
    @discardableResult
    public func initialize(timeout: Float = 20.0) -> Bool {
        initializeForFullUpdate(timeout: timeout)
    }

    /// Initialize the panel for the fast full update sequence.
    @discardableResult
    public func initializeFast(timeout: Float = 20.0) -> Bool {
        initializeForFastUpdate(timeout: timeout)
    }

    /// Reset the screen with the hardware reset pin.
    public func reset() {
        cs.high()
        rst.high()
        SwiftIO.sleep(ms: 200)
        rst.low()
        SwiftIO.sleep(ms: 2)
        rst.high()
        SwiftIO.sleep(ms: 200)
    }

    /// Display packed 2-bit-per-pixel data.
    ///
    /// The buffer must contain at least 10000 bytes. Bytes after the first
    /// 10000 are ignored.
    /// - Returns: `true` if the refresh busy wait completed before timeout.
    @discardableResult
    public func display(_ data: [UInt8], timeout: Float = 40.0) -> Bool {
        guard data.count >= Self.bufferSize else { return false }
        return data.withUnsafeBytes {
            display($0, timeout: timeout)
        }
    }

    /// Start writing packed image data into the display SRAM.
    ///
    /// After this command, call `writeDisplayData` one or more times until
    /// exactly 10000 image bytes have been sent, then call `refreshDisplay`.
    public func beginDisplayData() {
        writeCommand(.dataStartTransmission)
    }

    /// Write packed image data after `beginDisplayData`.
    public func writeDisplayData(_ data: [UInt8]) {
        writeData(data)
    }

    /// Write packed image data after `beginDisplayData`.
    public func writeDisplayData(_ data: UnsafeRawBufferPointer, count: Int) {
        writeData(data, count: count)
    }

    /// Refresh the display using the current SRAM contents.
    /// - Returns: `true` if the refresh busy wait completed before timeout.
    @discardableResult
    public func refreshDisplay(timeout: Float = 40.0) -> Bool {
        turnOnDisplay(timeout: timeout)
    }

    /// Clear the screen by sending one packed color byte repeatedly.
    /// - Returns: `true` if the refresh busy wait completed before timeout.
    @discardableResult
    public func clearScreen(_ color: Color = .white,
                            timeout: Float = 40.0) -> Bool {
        writeCommand(.dataStartTransmission)
        writeRepeatedData(color.packedValue, count: Self.bufferSize)
        return turnOnDisplay(timeout: timeout)
    }

    /// Enter deep sleep mode.
    /// - Returns: `true` if the power-off busy wait completed before timeout.
    @discardableResult
    public func sleep(timeout: Float = 20.0) -> Bool {
        writeConfig([0x00], to: .powerOff)
        let completed = waitUntilBusyHigh(timeout: timeout)
        writeConfig([0xA5], to: .deepSleep)
        pwr?.low()
        return completed
    }

    /// Wait using the polarity used by Waveshare's `ReadBusyH` helper.
    ///
    /// The reference driver waits while BUSY is low, then proceeds once BUSY is
    /// high. A timeout avoids locking the application if the panel is absent.
    /// - Returns: `true` if BUSY became high before timeout.
    @discardableResult
    public func waitUntilBusyHigh(timeout: Float = 20.0) -> Bool {
        SwiftIO.sleep(ms: 100)
        let start = getClockCycle()

        while !busy.read() {
            SwiftIO.sleep(ms: 5)
            if hasTimedOut(since: start, timeout: timeout) {
                return false
            }
        }

        return true
    }

    /// Wait using the opposite polarity present in Waveshare's unused
    /// `ReadBusy` helper.
    /// - Returns: `true` if BUSY became low before timeout.
    @discardableResult
    public func waitUntilBusyLow(timeout: Float = 20.0) -> Bool {
        SwiftIO.sleep(ms: 100)
        let start = getClockCycle()

        while busy.read() {
            SwiftIO.sleep(ms: 100)
            if hasTimedOut(since: start, timeout: timeout) {
                return false
            }
        }

        return true
    }
}


extension EPD1in54G {

    /// The four physical colors supported by this panel.
    public enum Color: UInt8 {
        case black = 0x00
        case white = 0x01
        case yellow = 0x02
        case red = 0x03

        public var packedValue: UInt8 {
            rawValue << 6 | rawValue << 4 | rawValue << 2 | rawValue
        }
    }

}


extension EPD1in54G {
    struct Command: RawRepresentable, Equatable {
        let rawValue: UInt8
        init(rawValue: UInt8) { self.rawValue = rawValue }

        static let panelSetting = Command(rawValue: 0x00)
        static let powerOff = Command(rawValue: 0x02)
        static let powerOn = Command(rawValue: 0x04)
        static let boosterSoftStart = Command(rawValue: 0x06)
        static let deepSleep = Command(rawValue: 0x07)
        static let dataStartTransmission = Command(rawValue: 0x10)
        static let displayRefresh = Command(rawValue: 0x12)
        static let pllControl = Command(rawValue: 0x30)
        static let panelSettingExtra = Command(rawValue: 0x4D)
        static let vcomAndDataInterval = Command(rawValue: 0x50)
        static let resolutionSetting = Command(rawValue: 0x61)
        static let fastModeControl = Command(rawValue: 0xA5)
        static let temperatureInputSelection = Command(rawValue: 0xE0)
        static let manualTemperature = Command(rawValue: 0xE6)
        static let commandE9 = Command(rawValue: 0xE9)
    }

    func writeConfigs(_ configs: [(address: Command, data: [UInt8]?)]) {
        for config in configs {
            writeConfig(config.data, to: config.address)
        }
    }

    func writeConfig(_ data: [UInt8]?, to address: Command) {
        writeCommand(address)
        if let data = data {
            writeData(data)
        }
    }

    func writeCommand(_ command: Command) {
        dc.low()
        cs.low()
        spi.write(command.rawValue)
        cs.high()
        dc.high()
    }

    func writeData(_ data: UInt8) {
        cs.low()
        spi.write(data)
        cs.high()
    }

    func writeData(_ data: [UInt8]) {
        cs.low()
        spi.write(data)
        cs.high()
    }

    func writeData(_ data: UnsafeRawBufferPointer, count: Int) {
        cs.low()
        spi.write(data, count: count)
        cs.high()
    }

    func writeRepeatedData(_ value: UInt8, count: Int) {
        let chunkSize = 256
        let chunk = [UInt8](repeating: value, count: chunkSize)
        var remaining = count

        while remaining > 0 {
            let writeCount = min(remaining, chunkSize)
            chunk.withUnsafeBytes {
                writeData($0, count: writeCount)
            }
            remaining -= writeCount
        }
    }

    @discardableResult
    func display(_ data: UnsafeRawBufferPointer,
                 timeout: Float = 40.0) -> Bool {
        guard data.count >= Self.bufferSize else { return false }

        writeCommand(.dataStartTransmission)
        writeData(data, count: Self.bufferSize)
        return turnOnDisplay(timeout: timeout)
    }

    @discardableResult
    func turnOnDisplay(timeout: Float = 40.0) -> Bool {
        writeConfig([0x00], to: .displayRefresh)
        return waitUntilBusyHigh(timeout: timeout)
    }

    func hasTimedOut(since start: UInt, timeout: Float) -> Bool {
        guard timeout > 0 else { return false }

        let current = getClockCycle()
        let elapsed = Float(cyclesToNanoseconds(start: start, stop: current))
            / 1_000_000_000
        return elapsed > timeout
    }
}
