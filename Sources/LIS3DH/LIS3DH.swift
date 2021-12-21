//=== LIS3DH.swift --------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Andy Liu
// Created: 05/11/2021
// Updated: 10/26/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for the LIS3DH accelerometer.
/// You can use the sensor to measure the accelerations in x, y, and z-axes.
///
/// The acceleration describes the change of velocity with time,
/// usually measured in m/s^2. The sensor measures it by detecting the force.
/// It can sense gravity and measure inertial force caused by movement.
/// They will change the internal capacitance of the sensor,
/// thus change the voltage in the circuit.
///
/// The sensor supports I2C and SPI protocol.
/// It will give raw readings between -32768 and 32767 (16-bit resolution).
/// The acceleration has direction so you will get positive or negative values.
/// The calculation of acceleration depends on the selected scaling range:
/// ±2, ±4, ±8  or ±16g. The raw reading will be mapped according to the range.
final public class LIS3DH {
    
    
    /// The ranges of the measurement.
    public enum GRange: UInt8 {
        /// The acceleration is from -2g to 2g. It is the default setting.
        case g2     = 0
        /// The acceleration is from -4g to 4g.
        case g4     = 0b0001_0000
        /// The acceleration is from -8g to 8g.
        case g8     = 0b0010_0000
        /// The acceleration is from -16g to 16g.
        case g16    = 0b0011_0000
    }
    
    
    /// The supported data rate for the sensor, 400Hz by default.
    public enum DataRate: UInt8 {
        case powerDown          = 0
        case Hz1                = 0b0001_0000
        case Hz10               = 0b0010_0000
        case Hz25               = 0b0011_0000
        case Hz50               = 0b0100_0000
        case Hz100              = 0b0101_0000
        case Hz200              = 0b0110_0000
        case Hz400              = 0b0111_0000
        case lowPowerHz1K6      = 0b1000_0000
        case Hz1K3LowPower5K    = 0b1001_0000
    }
    
    let defaultWhoAmI  = UInt8(0x33)
    
    let i2c: I2C?
    let address: UInt8?
    let spi: SPI?
    let csPin: DigitalOut?
    
    var gRange: GRange
    var dataRate: DataRate
    
    var rangeConfig: RangeConfig = []
    var dataRateConfig: DataRateConfig = []
    
    var gCoefficient: Float {
        switch gRange {
        case .g2:
            return 15987.0
        case .g4:
            return 7840.0
        case .g8:
            return 3883.0
        case .g16:
            return 1280.0
        }
    }

    private var readBuffer = [UInt8](repeating: 0, count: 6)
    
    
    /// Initialize the sensor using I2C communication.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   - address: **OPTIONAL** The device address of the sensor.
    public init(_ i2c: I2C, address: UInt8 = 0x18) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": ADXL345 only supports 100kbps and 400kbps I2C speed")
        }
        
        self.i2c = i2c
        self.address = address
        self.spi = nil
        self.csPin = nil
        
        rangeConfig = [.highResEnable]
        dataRateConfig = [.normalMode, .xEnable, .yEnable, .zEnable]
        
        gRange = .g2
        dataRate = .Hz400

        guard getDeviceID() == defaultWhoAmI else {
            fatalError(#function + ": cann't find LIS3DH at address \(address)")
        }
        
        setRange(gRange)
        setDataRate(dataRate)
        
        sleep(ms: 10)
    }

    /// Initialize the sensor using SPI communication.
    ///
    /// The maximum SPI clock speed is 10 MHz. Both the CPOL and CPHA of SPI
    /// should be true. And the cs pin should be set only once. You can set it
    /// when initializing an spi interface. If not, you need to set the cs when
    /// initializing the sensor.
    ///
    /// - Parameters:
    ///   - spi: **REQUIRED** The SPI interface that the sensor connects.
    ///   - csPin: **OPTIONAL** The cs pin for the spi.
    public init(_ spi: SPI, csPin: DigitalOut? = nil) {
        self.spi = spi
        self.csPin = csPin
        self.i2c = nil
        self.address = nil

        _ = spi.readByte()
        csPin?.high()

        rangeConfig = [.highResEnable]
        dataRateConfig = [.normalMode, .xEnable, .yEnable, .zEnable]

        gRange = .g2
        dataRate = .Hz400

        guard (spi.cs == false && csPin != nil && csPin!.getMode() == .pushPull)
                || (spi.cs == true && csPin == nil) else {
                    fatalError(#function + ": csPin isn't correct")
        }

        guard spi.getSpeed() <= 10_000_000 else {
            fatalError(#function + ": cannot support spi speed faster than 10MHz")
        }

        guard spi.getMode() == (true, true) else {
            fatalError(#function + ": spi mode doesn't match for LIS3DH")
        }

        guard getDeviceID() == defaultWhoAmI else {
            fatalError(#function + ": cannot find LIS3DH via spi bus")
        }

        setRange(gRange)
        setDataRate(dataRate)

        sleep(ms: 10)
    }
    
    /// Get the device ID from the sensor.
    /// It can be used to test if the sensor is connected. The ID should be 0x33.
    /// - Returns: The device ID.
    public func getDeviceID() -> UInt8 {
        return readRegister(.WHO_AM_I)
    }
    
    /// Set the scaling range of the sensor.
    /// The supported ranges are ±2, ±4, ±8 and ±16g.
    /// - Parameter newRange: The selected `GRange`.
    public func setRange(_ newRange: GRange) {
        gRange = newRange
        let newConfig = RangeConfig(rawValue: gRange.rawValue)
        rangeConfig.remove(.rangeMask)
        rangeConfig.insert(newConfig)
        writeRegister(rangeConfig.rawValue, to: .CTRL4)
    }
    
    /// Get the selected scaling range of the sensor.
    /// - Returns: The current range of measurement.
    public func getRange() -> GRange {
        let ret = readRegister(.CTRL4) & RangeConfig([.rangeMask]).rawValue
        return GRange(rawValue: ret)!
    }
    
    /// Set the data rate of the sensor.
    /// - Parameter newRate: The new data rate defined in `DataRate`.
    public func setDataRate(_ newRate: DataRate) {
        dataRate = newRate
        let newConfig = DataRateConfig(rawValue: dataRate.rawValue)
        dataRateConfig.remove(.dataRateMask)
        dataRateConfig.insert(newConfig)
        
        writeRegister(dataRateConfig.rawValue, to: .CTRL1)
    }
    
    /// Get current data rate.
    /// - Returns: The specified data rate.
    public func getDataRate() -> DataRate {
        let ret = readRegister(.CTRL1) & DataRateConfig([.dataRateMask]).rawValue
        return DataRate(rawValue: ret)!
    }
    
    
    /// Read raw values of acceleration on x, y, z-axes at once.
    /// - Returns: x, y, z values from -32768 to 32767.
    public func readRawValue() -> (x: Int16, y: Int16, z: Int16) {
        readRegister(.OUT_X_L, into: &readBuffer, count: 6)

        let x = Int16(readBuffer[0]) | (Int16(readBuffer[1]) << 8)
        let y = Int16(readBuffer[2]) | (Int16(readBuffer[3]) << 8)
        let z = Int16(readBuffer[4]) | (Int16(readBuffer[5]) << 8)
        
        return (x, y, z)
    }
    
    
    /// Read x, y, z acceleration values represented in g (9.8m/s^2)
    /// within the selected range.
    /// - Returns: 3 float within the selected g range.
    public func readValue() -> (x: Float, y: Float, z: Float) {
        let (ix, iy, iz) = readRawValue()
        var value: (x: Float, y: Float, z: Float) =
            (Float(ix), Float(iy), Float(iz))
        
        value.x = value.x / gCoefficient
        value.y = value.y / gCoefficient
        value.z = value.z / gCoefficient
        
        return value
    }
    
    /// Read the acceleration on x-axis.
    /// - Returns: A float representing the acceleration.
    public func readX() -> Float {
        readRegister(.OUT_X_L, into: &readBuffer, count: 2)
        let ix = Int16(readBuffer[0]) | (Int16(readBuffer[1]) << 8)
        
        return Float(ix) / gCoefficient
    }
    
    /// Read the acceleration on y-axis.
    /// - Returns: A float representing the acceleration.
    public func readY() -> Float {
        readRegister(.OUT_Y_L, into: &readBuffer, count: 2)
        let iy = Int16(readBuffer[0]) | (Int16(readBuffer[1]) << 8)
        
        return Float(iy) / gCoefficient
    }
    
    /// Read the acceleration on y-axis.
    /// - Returns: A float representing the acceleration.
    public func readZ() -> Float {
        readRegister(.OUT_Z_L, into: &readBuffer, count: 2)
        let iz = Int16(readBuffer[0]) | (Int16(readBuffer[1]) << 8)
        
        return Float(iz) / gCoefficient
    }
}


extension LIS3DH {
    enum Register: UInt8 {
        case STATUS_AUX     = 0x07
        case OUT_ADC1_L     = 0x08
        case OUT_ADC1_H     = 0x09
        case OUT_ADC2_L     = 0x0A
        case OUT_ADC2_H     = 0x0B
        case OUT_ADC3_L     = 0x0C
        case OUT_ADC3_H     = 0x0D
        case WHO_AM_I       = 0x0F
        
        case CTRL0          = 0x1E
        case TEMP_CFG       = 0x1F
        case CTRL1          = 0x20
        case CTRL2          = 0x21
        case CTRL3          = 0x22
        case CTRL4          = 0x23
        case CTRL5          = 0x24
        case CTRL6          = 0x25
        case REFERENCE      = 0x26
        case STATUS         = 0x27
        
        case OUT_X_L        = 0x28
        case OUT_X_H        = 0x29
        case OUT_Y_L        = 0x2A
        case OUT_Y_H        = 0x2B
        case OUT_Z_L        = 0x2C
        case OUT_Z_H        = 0x2D
        
        case FIFO_CTRL      = 0x2E
        case FIFO_SRC       = 0x2F
        
        case INT1_CFG       = 0x30
        case INT1_SRC       = 0x31
        case INT1_THS       = 0x32
        case INT1_DURATION  = 0x33
        case INT2_CFG       = 0x34
        case INT2_SRC       = 0x35
        case INT2_THS       = 0x36
        case INT2_DURATION  = 0x37
        
        case CLICK_CFG      = 0x38
        case CLICK_SRC      = 0x39
        case CLICK_THS      = 0x3A
        case TIME_LIMIT     = 0x3B
        case TIME_LATENCY   = 0x3C
        case TIME_WINDOW    = 0x3D
        case ACT_THS        = 0x3E
        case ACT_DUR        = 0x3F
    }
    
    struct RangeConfig: OptionSet {
        let rawValue: UInt8
        
        static let rangeMask       = RangeConfig(rawValue: 0b0011_0000)
        
        static let highResDisable  = RangeConfig([])
        static let highResEnable   = RangeConfig(rawValue: 0b1000)
    }
    
    struct DataRateConfig: OptionSet {
        let rawValue: UInt8
        
        static let dataRateMask     = DataRateConfig(rawValue: 0b1111_0000)
        
        static let normalMode       = DataRateConfig([])
        static let lowPowerMode     = DataRateConfig(rawValue: 0b1000)
        
        static let xEnable          = DataRateConfig(rawValue: 0b0001)
        static let yEnable          = DataRateConfig(rawValue: 0b0010)
        static let zEnable          = DataRateConfig(rawValue: 0b0100)
    }
    
    func writeRegister(_ value: UInt8, to reg: Register) {
        if let i2c = i2c {
            i2c.write([reg.rawValue, value], to: address!)
        } else if let spi = spi {
            csPin?.low()
            spi.write([reg.rawValue, value])
            csPin?.high()
        }
    }
    
    func readRegister(_ reg: Register) -> UInt8 {
        var byte: UInt8 = 0
        var ret: Result<(), Errno>

        if i2c != nil {
            ret = i2c!.writeRead(reg.rawValue, into: &byte, address: address!)
        } else {
            let register = reg.rawValue | 0b1000_0000
            csPin?.low()
            spi!.write(register)
            ret = spi!.read(into: &byte)
            csPin?.high()
        }

        if case .failure(let err) = ret {
            print("error: \(#function) " + String(describing: err))
        }
        return byte
    }
    
    func readRegister(_ beginReg: Register, into buffer: inout [UInt8], count: Int) {
        var writeByte = beginReg.rawValue
        writeByte |= 0x80

        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        if let i2c = i2c {
            i2c.writeRead(writeByte, into: &readBuffer,
                          readCount: count, address: address!)
        } else if let spi = spi {
            writeByte |= 0b1100_0000
            csPin?.low()
            spi.write(writeByte)
            spi.read(into: &buffer, count: count)
            csPin?.high()
        }

    }
}
