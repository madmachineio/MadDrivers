import SwiftIO

final public class LIS3DH {

    let defaultAddress = UInt8(0x18)
    let defaultWhoAmI  = UInt8(0x33)

    let spi: SPI?
    let cs: DigitalOut?

    let i2c: I2C!
    let address: UInt8

    var rangeConfig: RangeConfig = []
    var dataRateConfig: DataRateConfig = []

    public init(_ i2c: I2C, address: UInt8? = nil) {
        spi = nil
        cs = nil

        self.i2c = i2c
        if let add = address {
            self.address = add
        } else {
            self.address = defaultAddress
        }

        setRange([.g2, .highResEnable])
        setDataRate([.Hz400, .normalMode, .xEnable, .yEnable, .zEnable])
        sleep(ms: 10)
    }


    public func getDeviceID() -> UInt8 {
        return readRegister(.WHO_AM_I)
    }

    func setRange(_ config: RangeConfig) {
        rangeConfig = config
        writeRegister(rangeConfig.rawValue, to: .CTRL4)
    }

    public func getRange() -> UInt8 {
        return readRegister(.CTRL4)
    }

    public func getDataRate() -> UInt8 {
        return readRegister(.CTRL1)
    }

    func setDataRate(_ config: DataRateConfig) {
        dataRateConfig = config
        writeRegister(dataRateConfig.rawValue, to: .CTRL1)
    }

    public func readRawValue() -> (x: Int16, y: Int16, z: Int16) {
        let rawValues = readRegister(.OUT_X_L, count: 6)
        guard rawValues.count == 6 else { return (0, 0, 0) }
        let x = Int16(rawValues[0]) | (Int16(rawValues[1]) << 8)
        let y = Int16(rawValues[2]) | (Int16(rawValues[3]) << 8)
        let z = Int16(rawValues[4]) | (Int16(rawValues[5]) << 8)

        return (x, y, z)
    }
    
    func writeRegister(_ value: UInt8, to reg: Register) {
        i2c.write([reg.rawValue, value], to: address)
    }

    func readRegister(_ reg: Register) -> UInt8 {
        let data = i2c.writeRead([reg.rawValue], readCount: 1, address: address)
        if data.count > 0 {
            return data[0]
        } else {
            return 0
        }
    }

    func readRegister(_ beginReg: Register, count: Int) -> [UInt8] {
        var writeByte = beginReg.rawValue

        writeByte |= 0x80

        let data = i2c.writeRead([writeByte], readCount: count, address: address)
        return data
    }

    func writeRegister(_ reg: Register) {

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

        static let g2   = RangeConfig([])
        static let g4   = RangeConfig(rawValue: 0b0001_0000)
        static let g8   = RangeConfig(rawValue: 0b0010_0000)
        static let g16  = RangeConfig(rawValue: 0b0011_0000)

        static let highResDisable  = RangeConfig([])
        static let highResEnable   = RangeConfig(rawValue: 0b1000)
    }

    struct DataRateConfig: OptionSet {
        let rawValue: UInt8

        static let powerDown        = DataRateConfig([])
        static let Hz1              = DataRateConfig(rawValue: 0b0001_0000)
        static let Hz10             = DataRateConfig(rawValue: 0b0010_0000)
        static let Hz25             = DataRateConfig(rawValue: 0b0011_0000)
        static let Hz50             = DataRateConfig(rawValue: 0b0100_0000)
        static let Hz100            = DataRateConfig(rawValue: 0b0101_0000)
        static let Hz200            = DataRateConfig(rawValue: 0b0110_0000)
        static let Hz400            = DataRateConfig(rawValue: 0b0111_0000)
        static let lowPowerHz1K6    = DataRateConfig(rawValue: 0b1000_0000)
        static let Hz1K3LowPower5K  = DataRateConfig(rawValue: 0b1001_0000)
        
        static let normalMode       = DataRateConfig([])
        static let lowPowerMode     = DataRateConfig(rawValue: 0b1000)

        static let xEnable          = DataRateConfig(rawValue: 0b0001)
        static let yEnable          = DataRateConfig(rawValue: 0b0010)
        static let zEnable          = DataRateConfig(rawValue: 0b0100)
    }
}