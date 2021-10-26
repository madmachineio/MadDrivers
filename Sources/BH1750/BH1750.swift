import SwiftIO

/// This is the library for the BH1750 light sensor.
///
/// The sensor communicates with your board via an I2C bus.
/// It provides 16-bit resolution to sense the amount of ambiant light. The light will be 0 to 65535 lux (lx).
final public class BH1750 {
    
    let i2c: I2C
    let address: UInt8
    
    let mode: Mode
    var resolution: Resolution
    
    /// It decides if the sensor will measure the light all the time or just once.
    public enum Mode: UInt8 {
        /// The sensor will read the ambient light continuously.
        case continuous = 0b0001_0000
        /// The sensor will read once and move to powered down mode until the next reading.
        case oneTime = 0b0010_0000
    }
    
    /// It decides the precision of the measurement. By default, you will choose the middle one.
    public enum Resolution: UInt8 {
        /// Start measurement at 0.5lx resolution.
        case high = 0b0001
        /// Start measurement at 1lx resolution.
        case middle = 0b0000
        /// Start measurement at 4lx resolution.
        case low = 0b0011
    }
    
    /// Initialize the light sensor.
    /// - Parameters:
    ///   - i2c: **REQUIRED** An I2C pin for the communication.
    ///   - address: **OPTIONAL** The sensor's address. It has a default value.
    ///   - mode: **OPTIONAL** Whether the sensor measures once or continuously. `.continuous` by default.
    ///   - resolution: **OPTIONAL** The resolution for the measurement. `.middle` by default.
    public init(_ i2c: I2C, address: UInt8 = 0x23,
                mode: Mode = .continuous, resolution: Resolution = .middle) {
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
        let rawValue = readRawValue()
        
        return Float(rawValue) * unit / 1.2
    }
}

extension BH1750 {
    private enum Setting: UInt8 {
        case powerOn = 0b0001
        case reset = 0b0111
    }
    
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
    
    private func writeCommand(_ value: UInt8) {
        i2c.write(value, to: address)
    }
    
    func reset() {
        writeCommand(Setting.powerOn.rawValue)
        writeCommand(Setting.reset.rawValue)
    }
    
    func setResolution(_ resolution: Resolution) {
        self.resolution = resolution
        
        let configValue = mode.rawValue | resolution.rawValue
        writeCommand(configValue)
        sleep(ms: measurementTime)
    }
    
    func readRawValue() -> UInt16 {
        var value: [UInt8]
        
        switch mode {
        case .continuous:
            /// In this mode, the sensor measures the light continuously, so you can read directly.
            value = i2c.read(count: 2, from: address)
        case .oneTime:
            /// In this mode, every time the sensor finishes the reading, the sensor will be powered down.
            /// You need to resend the command for a new reading.
            let configValue = mode.rawValue | resolution.rawValue
            writeCommand(configValue)
            sleep(ms: measurementTime)
            value = i2c.read(count: 2, from: address)
        }
        
        return UInt16(value[0]) << 8 | UInt16(value[1])
    }
}
