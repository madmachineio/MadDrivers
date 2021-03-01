import SwiftIO

final public class VEML6040 {
    public enum Reg: UInt8 {
        case config = 0x00
        case redData = 0x08
        case greenData = 0x09
        case blueData = 0x0A
        case whiteData = 0x0B
    }

    struct Config: OptionSet {
        let rawValue: UInt8

        static let _integration40ms = Config([])
        static let _integration80ms = Config(rawValue: 0b0001_0000)
        static let _integration160ms = Config(rawValue: 0b0010_0000)
        static let _integration320ms = Config(rawValue: 0b0011_0000)
        static let _integration640ms = Config(rawValue: 0b0100_0000)
        static let _integration1280ms = Config(rawValue: 0b0101_0000)

        static let noTrig = Config([])
        static let trig = Config(rawValue: 0b0100)

        static let autoMode = Config([])
        static let fouceMode = Config(rawValue: 0b10)

        static let enable = Config([])
        static let disable = Config(rawValue: 0b1)

    }

    static let gSens40ms: Float = 0.25168

    public let address: UInt8
	public let i2c: I2C

    private var configValue: Config = [._integration160ms, .noTrig, .autoMode]
    
    // Initialize the I2C bus and reset the sensor to prepare for the following commands.
    public init(_ i2c: I2C, address: UInt8 = 0x10) {
        self.i2c = i2c
        self.address = address

        writeConfig([configValue, .disable])
        writeConfig([configValue, .enable])
    }

    
	// Split the 16-bit data into two 8-bit data. 
    // Write the data to the default address of the sensor.
    func writeConfig(_ value: Config) {
        let array: [UInt8] = [Reg.config.rawValue, value.rawValue, 0]
        i2c.write(array, to: address)
    }

    func readRegister(_ reg: Reg) -> UInt16 {
        i2c.write(reg.rawValue, to: address)
        let data = i2c.read(count: 2, from: address)
        return (UInt16(data[1]) << 8) | UInt16(data[0])
    }
    
    public func readRed() -> UInt16 {
        return readRegister(.redData)
    }
    public func readGreen() -> UInt16 {
        return readRegister(.greenData)
    }
    public func readBlue() -> UInt16 {
        return readRegister(.blueData)
    }
    public func readWhite() -> UInt16 {
        return readRegister(.whiteData)
    }
}