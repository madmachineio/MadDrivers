//=== MS5611.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 3/11/2023
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for MS5611 Barometric Pressure Sensor.
///
/// MS5611 uses a MEMS pressure sensor with a resolution of 24 bits.
/// It contains temperatuer sensor which can be used for temperature compensation
/// of the pressure measurements.
final public class MS5611 {
    private let i2c: I2C?
    private let address: UInt8?
    private let spi: SPI?
    private let csPin: DigitalOut?

    var coefficient: [UInt16] = []
    var resolution: Resolution

    /// Initialize the sensor using I2C communication.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   - address: **OPTIONAL** The device address of the sensor.
    public init(_ i2c: I2C, address: UInt8 = 0x77) {
        self.i2c = i2c
        self.address = address
        self.spi = nil
        self.csPin = nil

        resolution = .osr4096

        try? reset()
        coefficient = readPROM()
    }

    /// Initialize the sensor using SPI communication.
    ///
    /// The maximum supporting SPI clock speed is 20 MHz.
    /// The CPOL and CPHA of SPI should be both true or both false.
    /// And the cs pin should be set only once, either when initializing the spi
    /// interface or when initializing the sensor.
    /// - Parameters:
    ///   - spi: **REQUIRED** The SPI interface that the sensor connects.
    ///   - csPin: **OPTIONAL** The cs pin for the spi.
    public init(_ spi: SPI, csPin: DigitalOut? = nil) {
        self.spi = spi
        self.csPin = csPin
        self.i2c = nil
        self.address = nil

        csPin?.high()

        guard (spi.cs == false && csPin != nil && csPin!.getMode() == .pushPull)
                || (spi.cs == true && csPin == nil) else {
                    print(#function + ": csPin isn't correctly configured")
                    fatalError()
        }

        guard spi.getSpeed() <= 20_000_000 else {
            print(#function + ": MS5611 cannot support SPI speed faster than 20MHz")
            fatalError()
        }

        guard spi.getMode() == (true, true, .MSB) || spi.getMode() == (false, false, .MSB) else {
            print(#function + ": SPI mode doesn't match for MS5611. CPOL and CPHA should be both true or both false and bitOrder should be .MSB")
            fatalError()
        }

        resolution = .osr4096

        try? reset()
        coefficient = readPROM()
    }

    /// Get the temperature in Celsius and pressure in mbar. 1mbar equals 100pascals (Pa).
    /// - Returns: Temperature in Celsius and pressure in mbar.
    public func read() -> (temperature: Float, pressure: Float) {
        let rawPressure = readRawPressure()
        let rawTemp = readRawTemperature()

        let dT = Int64(rawTemp) - Int64(coefficient[5]) << 8
        var temperature = 2000 + (dT * Int64(coefficient[6])) >> 23

        var off = Int64(coefficient[2]) << 16 + (Int64(coefficient[4]) * dT) >> 7
        var sens = Int64(coefficient[1]) << 15 + (Int64(coefficient[3]) * dT) >> 8

        if temperature < 2000 {
            let t2 = (dT * dT) >> 31
            var off2 = 5 * (temperature - 2000) * (temperature - 2000) / 2
            var sens2 = 5 * (temperature - 2000) * (temperature - 2000) / 4

            if temperature < -15 {
                off2 += 7 * (temperature + 1500) * (temperature + 1500)
                sens2 += 11 * (temperature + 1500) * (temperature + 1500) / 2
            }

            temperature -= t2
            off -= off2
            sens -= sens2
        }

        let pressure = (Int64(rawPressure) * (sens >> 21) - off) >> 15

        return (Float(temperature) / 100, Float(pressure) / 100)
    }
}

extension MS5611 {
    enum Command: UInt8 {
        case adcRead = 0x00
        case promRead = 0xA0
        case reset = 0x1E
        case convertD1 = 0x40
        case convertD2 = 0x50
    }

    enum Resolution: UInt8 {
        case osr256
        case osr512
        case osr1024
        case osr2048
        case osr4096

        var conversionTime: Int {
            switch self {
            case .osr256:
                // Max conversion time is 0.6ms.
                return 1
            case .osr512:
                // Max conversion time is 1.17ms.
                return 2
            case .osr1024:
                // Max conversion time is 2.28ms.
                return 3
            case .osr2048:
                // Max conversion time is 4.54ms.
                return 5
            case .osr4096:
                // Max conversion time is 9.04ms.
                return 10
            }
        }
    }

    private func writeCommand(_ command: UInt8) throws(Errno) {
        var result: Result<(), Errno>
        if let i2c {
            result = i2c.write(command, to: address!)
        } else {
            csPin?.low()
            result = spi!.write(command)
            csPin?.high()
        }
        if case .failure(let err) = result {
            throw err
        }
    }

    func readCommand(_ command: UInt8, into buffer: inout [UInt8], count: Int) throws(Errno) {
        var result: Result<(), Errno>

        for i in buffer.indices {
            buffer[i] = 0
        }

        if let i2c, let address {
            result = i2c.write(command, to: address)
            if case .failure(let err) = result {
                throw err
            }
            result = i2c.read(into: &buffer, count: count, from: address)
        } else {
            var tempBuffer = [UInt8](repeating: 0, count: count + 1)
            csPin?.low()
            result = spi!.transceive(command, into: &tempBuffer, readCount: count + 1)
            csPin?.high()

            for i in 0..<count {
                buffer[i] = tempBuffer[i + 1]
            }
        }

        if case .failure(let err) = result {
            throw err
        }
    }

    private func reset() throws(Errno) {
        try writeCommand(Command.reset.rawValue)
        sleep(ms: 3)
    }

    /// Get the calibration coefficients.
    private func readPROM() -> [UInt16] {
        var coefficients: [UInt16] = []
        for i in 0..<7 {
            var buffer: [UInt8] = [0, 0]
            try? readCommand(Command.promRead.rawValue + UInt8(i * 2), into: &buffer, count: 2)
            coefficients.append(UInt16(buffer[0]) << 8 | UInt16(buffer[1]))
        }

        return coefficients
    }

    /// Initiate pressure or temperature conversion using the given resultion.
    /// The sensor stays busy until conversion is done.
    private func convert(_ command: Command, resolution: Resolution) {
        try? writeCommand(command.rawValue + resolution.rawValue * 2)
        sleep(ms: resolution.conversionTime)
    }

    /// After the conversion is finished, read raw value from ADC.
    /// If the conversion is not executed before the ADC read command,
    /// or the ADC read command is repeated, it will give 0 as the output result.
    private func readADC() -> UInt32 {
        var buffer = [UInt8](repeating: 0, count: 3)
        try? readCommand(Command.adcRead.rawValue, into: &buffer, count: 3)
        return (UInt32(buffer[0]) << 16) | (UInt32(buffer[1]) << 8) | UInt32(buffer[2])
    }

    private func readRawTemperature() -> UInt32 {
        convert(.convertD2, resolution: resolution)
        return readADC()
    }

    private func readRawPressure() -> UInt32 {
        convert(.convertD1, resolution: resolution)
        return readADC()
    }
}
