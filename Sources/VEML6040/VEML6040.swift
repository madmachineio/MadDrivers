import SwiftIO

final public class VEML6040 {
    
    public enum IntegrationTime: UInt8 {
        case i40ms      = 0
        case i80ms      = 0b0001_0000
        case i160ms     = 0b0010_0000
        case i320ms     = 0b0011_0000
        case i640ms     = 0b0100_0000
        case i1280ms    = 0b0101_0000
    }
    
    public let address: UInt8
    public let i2c: I2C
    
    public var sensitivity: Float {
        switch integrationTime {
        case .i40ms:
            return 0.25168
        case .i80ms:
            return 0.12584
        case .i160ms:
            return 0.06292
        case .i320ms:
            return 0.03146
        case .i640ms:
            return 0.01573
        case .i1280ms:
            return 0.007865
        }
    }
    
    public var maxLux: Int {
        switch integrationTime {
        case .i40ms:
            return 16496
        case .i80ms:
            return 8248
        case .i160ms:
            return 4124
        case .i320ms:
            return 2062
        case .i640ms:
            return 1031
        case .i1280ms:
            return 515
        }
    }
    
    private var integrationTime: IntegrationTime
    private var configValue: Config
    
    // Initialize the I2C bus and reset the sensor to prepare for the following commands.
    public init(_ i2c: I2C, address: UInt8 = 0x10) {
        self.i2c = i2c
        self.address = address
        
        configValue = [.noTrig, .autoMode]
        integrationTime = .i160ms
        
        setIntegrationTime(integrationTime)
    }
    
    public func setIntegrationTime(_ newValue: IntegrationTime) {
        integrationTime = newValue
        let newConfig = Config(rawValue: integrationTime.rawValue)
        configValue.remove(.integrationTimeMask)
        configValue.insert(newConfig)
        
        writeConfig(configValue)
    }
    
    public func getIntegrationTime() -> IntegrationTime {
        return integrationTime
    } 
    
    public func readRedRawValue() -> UInt16 {
        return readRegister(.redData)
    }
    public func readGreenRawValue() -> UInt16 {
        return readRegister(.greenData)
    }
    public func readBlueRawValue() -> UInt16 {
        return readRegister(.blueData)
    }
    public func readWhiteRawValue() -> UInt16 {
        return readRegister(.whiteData)
    }
    
    public func readRed() -> Int {
        return calcLux(readRedRawValue())
    }
    
    public func readGreen() -> Int {
        return calcLux(readGreenRawValue())
    }
    
    public func readBlue() -> Int {
        return calcLux(readBlueRawValue())
    }
    
    public func readWhite() -> Int {
        return calcLux(readWhiteRawValue())
    }
}


extension VEML6040 {
    private enum Reg: UInt8 {
        case config = 0x00
        case redData = 0x08
        case greenData = 0x09
        case blueData = 0x0A
        case whiteData = 0x0B
    }
    
    private struct Config: OptionSet {
        let rawValue: UInt8
        
        static let integrationTimeMask = Config(rawValue: 0b0111_0000)
        
        static let noTrig = Config([])
        static let trig = Config(rawValue: 0b0100)
        
        static let autoMode = Config([])
        static let fouceMode = Config(rawValue: 0b10)
        
        static let enable = Config([])
        static let disable = Config(rawValue: 0b1)
        
    }
    
    // Split the 16-bit data into two 8-bit data.
    // Write the data to the default address of the sensor.
    private func writeConfig(_ value: Config) {
        let array: [UInt8] = [Reg.config.rawValue, value.rawValue, 0]
        i2c.write(array, to: address)
    }
    
    private func readRegister(_ reg: Reg) -> UInt16 {
        let data = i2c.writeRead(reg.rawValue, readCount: 2, address: address)
        return (UInt16(data[1]) << 8) | UInt16(data[0])
    }
    
    private func calcLux(_ rawValue: UInt16) -> Int {
        return Int(Float(rawValue) * sensitivity)
    }
}
