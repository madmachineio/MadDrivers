//=== BMP280.swift --------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 12/04/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO
import RealModule

/// This is the library for BMP280 temperature and pressure sensor.
///
/// The sensor supports both I2C and SPI communication. The temperature reading
/// will be returned in degree Celsius. The barometric pressure is in hPa (100 Pascal).
/// And you can calculate the altitude based on the pressure.
final public class BMP280 {
    private let i2c: I2C?
    private let spi: SPI?
    private let address: UInt8?
    private let csPin: DigitalOut?

    private var readBuffer = [UInt8](repeating: 0, count: 24 + 1)

    private var tSampling: Oversampling
    private var pSampling: Oversampling
    private var mode: Mode
    private var standby: Standby
    private var filter: Filter
    private var calibration: [Double] = []

    /// Initialize the sensor using I2C communication.
    ///
    /// - Attention: The sensor's address depends on the pin SDO. If you connect
    /// the pin to GND, the address is 0x76. If you connect the pin to power,
    /// the address if 0x77. If the pin is unconnected, the address is undefined.
    ///
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   - address: **OPTIONAL** The device address of the sensor.
    public init(_ i2c: I2C, address: UInt8 = 0x77) {
        self.i2c = i2c
        self.spi = nil
        self.csPin = nil
        self.address = address

        tSampling = .x2
        pSampling = .x16
        mode = .normal

        standby = .ms05
        filter = .x16

        guard getDeviceID() == 0x58 else {
            fatalError(#function + ": cannot find BMP280 at address \(address)")
        }

        reset()
        writeConfig()
        writeCtrlMeas()
        calibration = readCalibration()
    }

    /// Initialize the sensor using SPI communication.
    ///
    ///  The CPOL and CPHA of SPI
    /// should be both true or both false. And the cs pin should be set only once.
    /// You can set it when initializing an spi interface. If not, you need to
    /// set the cs when initializing the sensor.
    ///
    /// - Parameters:
    ///   - spi: **REQUIRED** The SPI interface that the sensor connects.
    ///   The maximum SPI clock speed is **10MHz**. The **CPOL and CPHA**
    ///   should be **both true** or **both false**.
    ///   - csPin: **OPTIONAL** The cs pin for the spi.
    public init(_ spi: SPI, csPin: DigitalOut? = nil) {
        self.spi = spi
        self.csPin = csPin
        self.i2c = nil
        self.address = nil

        csPin?.high()

        tSampling = .x2
        pSampling = .x16
        mode = .normal

        standby = .ms05
        filter = .x16

        guard (spi.cs == false && csPin != nil && csPin!.getMode() == .pushPull)
                || (spi.cs == true && csPin == nil) else {
                    fatalError(#function + ": csPin isn't correct")
        }

        guard spi.getMode() == (true, true, .MSB) ||
                spi.getMode() == (false, false, .MSB) else {
            fatalError(#function + ": spi mode doesn't match for BMP280")
        }

        guard spi.getSpeed() <= 10_000_000 else {
            fatalError(#function + ": cannot support spi speed faster than 10MHz")
        }

        guard getDeviceID() == 0x58 else {
            fatalError(#function + ": cannot find BMP280 via spi bus")
        }

        reset()
        writeConfig()
        writeCtrlMeas()
        calibration = readCalibration()
    }



    /// Read current temperature in Celsius.
    /// - Returns: The temperature in Celsius.
    public func readTemperature() -> Double {
        if mode != .normal {
            setMode(.force)
            var byte: UInt8 = 0
            try? readRegister(.status, into: &byte)
            while byte >> 3 == 1 {
                sleep(ms: 2)
            }
        }

        // Ignore the value 0x80000 when the measurment is skipped.
        while readRawValue(.temp) == 0x80000 {
            sleep(ms: 2)
        }

        let raw = readRawValue(.temp)

        let var1 = (raw / 16384.0 - calibration[0] / 1024.0) * calibration[1]
        let var2 = (raw / 131072.0 - calibration[0] / 8192.0) *
        (raw / 131072.0 - calibration[0] / 8192.0) * calibration[2]

        let temp = (var1 + var2) / 5120.0
        return temp
    }

    /// Measure current barometric pressure in hPa.
    /// - Returns: Current pressure in hPa.
    public func readPressure() -> Double {
        let temp = readTemperature()
        let rawValue = readRawValue(.pressure)

        var var1 = temp * 5120.0 / 2.0 - 64000.0
        var var2 = var1 * var1 * calibration[8] / 32768.0
        var2 = var2 + var1 * calibration[7] * 2.0

        var2 = var2 / 4.0 + calibration[6] * 65536.0
        let var3 = calibration[5] * var1 * var1 / 524288.0
        var1 = (var3 + calibration[4] * var1) / 524288.0
        var1 = (1.0 + var1 / 32768.0) * calibration[3]
        if var1 == 0 {
            return 0
        }
        var pressure = 1048576.0 - rawValue
        pressure = ((pressure - var2 / 4096.0) * 6250.0) / var1

        var1 = calibration[11] * pressure * pressure / 2147483648.0
        var2 = pressure * calibration[10] / 32768.0
        pressure = pressure + (var1 + var2 + calibration[9]) / 16.0
        pressure /= 100

        return pressure
    }

    /// Calculate the altitude above sea level in meter.
    ///
    /// The altitude is calculated based on the sea level pressure.
    /// You can find the current sea level pressure here:
    /// https://weather.us/observations/usa/pressure-qff/20211203-0400z.html
    /// - Parameter seaLevelPressure: The sea level pressure in hPa.
    /// - Returns: The altitude in meter.
    public func readAltitude(_ seaLevelPressure: Double) -> Double {
        let pressure = readPressure()
        let altitude = 44330 * (1.0 - Double.pow(pressure / seaLevelPressure, 0.1903))
        return altitude
    }

    /// Get IIR filter setting for the measurement.
    /// - Returns: A filter level in `Filter` enumeration.
    public func getFilter() -> Filter {
        return self.filter
    }

    /// Set IIR filter level for the measurement.
    /// - Parameter filter: A filter setting in `Filter` enumeration.
    public func setFilter(_ filter: Filter) {
        self.filter = filter
        writeConfig()
    }

    /// Get the standby duration for the measurement in normal mode.
    /// - Returns: A standby duration in `Standby` enumeration.
    public func getStandby() -> Standby {
        return self.standby
    }

    /// Set the standby duration after each measurement in normal mode.
    /// - Parameter standby: A standby duration in `Standby` enumeration.
    public func setStandby(_ standby: Standby) {
        self.standby = standby
        writeConfig()
    }

    /// Get current power mode.
    /// - Returns: A mode in the `Mode` enumeration.
    public func getMode() -> Mode {
        return self.mode
    }

    /// Set the power mode to change how the sensor measures data.
    /// - Parameter mode: A mode in the `Mode` enumeration.
    public func setMode(_ mode: Mode) {
        self.mode = mode
        writeCtrlMeas()
    }

    /// Get oversampling rate for the temperature measurement.
    /// - Returns: An Oversampling setting.
    public func getTempOversampling() -> Oversampling {
        return self.tSampling
    }

    /// Set oversampling rate for the temperature measurement.
    /// - Parameter tSampling: An Oversampling setting.
    public func setTempOversampling(_ tSampling: Oversampling) {
        self.tSampling = tSampling
        writeCtrlMeas()
    }

    /// Get oversampling rate for the pressure measurement.
    /// - Returns: A Oversampling setting.
    public func getPressureOversampling() -> Oversampling {
        return self.pSampling
    }

    /// Set oversampling rate for the pressure measurement.
    /// - Parameter pSampling: A Oversampling setting.
    public func setPressureOversampling(_ pSampling: Oversampling) {
        self.pSampling = pSampling
        writeCtrlMeas()
    }

    /// Reset the sensor.
    public func reset() {
        try? writeRegister(.reset, 0xB6)
        sleep(ms: 4)
    }

    /// Standby duration after each measurement in normal mode.
    public enum Standby: UInt8 {
        /// 0.5 ms standby.
        case ms05 = 0b000
        /// 62.5 ms standby.
        case ms62 = 0b001
        /// 125 ms standby.
        case ms125 = 0b010
        /// 250 ms standby.
        case ms250 = 0b011
        /// 500 ms standby.
        case ms500 = 0b100
        /// 1000 ms standby.
        case ms1000 = 0b101
        /// 2000 ms standby.
        case ms2000 = 0b110
        /// 4000 ms standby.
        case ms4000 = 0b111
      }

    /// IIR filter coefficient for the sensor to minimize the disturbances.
    public enum Filter: UInt8 {
        case disable = 0b000
        case x2 = 0b001
        case x4 = 0b010
        case x8 = 0b011
        case x16 = 0b100
      }

    /// Oversampling rate for temperature and pressure measurement.
    public enum Oversampling: UInt8 {
        case disable = 0
        case x1 = 0b001
        case x2 = 0b010
        case x4 = 0b011
        case x8 = 0b100
        case x16 = 0b101
    }

    /// Power mode. It decides how the sensor performs the measurement.
    public enum Mode: UInt8 {
        /// The default mode after power on. No measurements will be performed.
        case sleep = 0b00
        /// The device performs a single measurement and then enter sleep mode.
        case force = 0b01
        /// The device will perform measurement periodically.
        case normal = 0b11
    }
}

extension BMP280 {
    enum Register: UInt8 {
        case chipID = 0xD0
        case reset = 0xE0
        case digT1 = 0x88
        case status = 0xF3
        case ctrlMeas = 0xF4
        case config = 0xF5
        case pressure = 0xF7
        case temp = 0xFA
    }

    private func writeRegister(_ register: Register, _ value: UInt8) throws {
        var result: Result<(), Errno>

        if i2c != nil {
            result = i2c!.write([register.rawValue, value], to: address!)
        } else {
            let register = register.rawValue & 0b0111_1111
            csPin?.low()
            result = spi!.write([register, value])
            csPin?.high()
        }

        if case .failure(let err) = result {
            throw err
        }
    }

    private func readRegister(
        _ register: Register, into byte: inout UInt8
    ) throws {
        var result: Result<(), Errno>

        if i2c != nil {
            result = i2c!.write(register.rawValue, to: address!)
            if case .failure(let err) = result {
                throw err
            }
            result = i2c!.read(into: &byte, from: address!)
        } else {
            let register = register.rawValue | 0b1000_0000
            var tempBuffer: [UInt8] = [0, 0]
            csPin?.low()
            result = spi!.transceive(register, into: &tempBuffer)
            csPin?.high()
            byte = tempBuffer[1]
        }

        if case .failure(let err) = result {
            throw err
        }
    }

    private func readRegister(
        _ register: Register, into buffer: inout [UInt8], count: Int
    ) throws {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        var result: Result<(), Errno>
        if i2c != nil {
            result = i2c!.write(register.rawValue, to: address!)
            if case .failure(let err) = result {
                throw err
            }
            result = i2c!.read(into: &buffer, from: address!)
        } else {
            let register = register.rawValue | 0b1000_0000
            csPin?.low()
            result = spi!.transceive(register, into: &buffer, readCount: count + 1)
            csPin?.high()
            for i in 0..<count {
                buffer[i] = buffer[i+1]
            }
        }

        if case .failure(let err) = result {
            throw err
        }
    }

    private func getDeviceID() -> UInt8 {
        var byte: UInt8 = 0
        try? readRegister(.chipID, into: &byte)
        return byte
    }

    /// Set standby duration and filter.
    private func writeConfig() {
        var config: UInt8 = 0

        if mode == .normal {
            /// In normal mode, write to config register will be ingnored.
            setMode(.sleep)
            config = (standby.rawValue << 5) | filter.rawValue
            try? writeRegister(.config, config)
            setMode(.normal)
        } else {
            config = filter.rawValue
            try? writeRegister(.config, config)
        }
    }

    /// Set the data acquisition option of the device:
    /// temperature and pressure oversampling and mode.
    private func writeCtrlMeas() {
        let ctrlMeas = tSampling.rawValue << 5 | pSampling.rawValue << 2 | mode.rawValue
        try? writeRegister(.ctrlMeas, ctrlMeas)
    }

    /// Read temperature or pressure raw value.
    private func readRawValue(_ register: Register) -> Double {
        try? readRegister(register, into: &readBuffer, count: 3)
        let raw = UInt32(readBuffer[0]) << 12 |
        UInt32(readBuffer[1]) << 4 | UInt32(readBuffer[2] >> 4)

        return Double(raw)
    }

    private func readCalibration() -> [Double] {
        try? readRegister(.digT1, into: &readBuffer, count: 24)

        let t1 = Double(UInt16(readBuffer[0]) | (UInt16(readBuffer[1]) << 8))
        let t2 = Double(Int16(readBuffer[2]) | (Int16(readBuffer[3]) << 8))
        let t3 = Double(Int16(readBuffer[4]) | (Int16(readBuffer[5]) << 8))

        let p1 = Double(UInt16(readBuffer[6]) | (UInt16(readBuffer[7]) << 8))
        let p2  = Double(Int16(readBuffer[8]) | (Int16(readBuffer[9]) << 8))
        let p3  = Double(Int16(readBuffer[10]) | (Int16(readBuffer[11]) << 8))
        let p4  = Double(Int16(readBuffer[12]) | (Int16(readBuffer[13]) << 8))
        let p5  = Double(Int16(readBuffer[14]) | (Int16(readBuffer[15]) << 8))
        let p6  = Double(Int16(readBuffer[16]) | (Int16(readBuffer[17]) << 8))
        let p7  = Double(Int16(readBuffer[18]) | (Int16(readBuffer[19]) << 8))
        let p8  = Double(Int16(readBuffer[20]) | (Int16(readBuffer[21]) << 8))
        let p9  = Double(Int16(readBuffer[22]) | (Int16(readBuffer[23]) << 8))

        let calibration = [t1, t2, t3, p1, p2, p3, p4, p5, p6, p7, p8, p9]
        return calibration
    }
}
