import SwiftIO

final public class LIS3DH {

    public enum GRange: UInt8 {
        case g2     = 0
        case g4     = 0b0001_0000
        case g8     = 0b0010_0000
        case g16    = 0b0011_0000
    }

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

    let i2c: I2C
    let address: UInt8

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

    public init(_ i2c: I2C, address: UInt8 = 0x18) {
        self.i2c = i2c
        self.address = address

        rangeConfig = [.highResEnable]
        dataRateConfig = [.normalMode, .xEnable, .yEnable, .zEnable]

        gRange = .g2
        dataRate = .Hz400

        setRange(gRange)
        setDataRate(dataRate)

        sleep(ms: 10)
    }

    public func getDeviceID() -> UInt8 {
        return readRegister(.WHO_AM_I)
    }

    public func setRange(_ newRange: GRange) {
        gRange = newRange
        let newConfig = RangeConfig(rawValue: gRange.rawValue)
        rangeConfig.remove(.rangeMask)
        rangeConfig.insert(newConfig)
        writeRegister(rangeConfig.rawValue, to: .CTRL4)
    }

    public func getRange() -> GRange {
        let ret = readRegister(.CTRL4) & RangeConfig([.rangeMask]).rawValue
        return GRange(rawValue: ret)!
    }

    public func setDataRate(_ newRate: DataRate) {
        dataRate = newRate
        let newConfig = DataRateConfig(rawValue: dataRate.rawValue)
        dataRateConfig.remove(.dataRateMask)
        dataRateConfig.insert(newConfig)

        writeRegister(dataRateConfig.rawValue, to: .CTRL1)
    }

    public func getDataRate() -> DataRate {
        let ret = readRegister(.CTRL1) & DataRateConfig([.dataRateMask]).rawValue
        return DataRate(rawValue: ret)!
    }

    public func readRawValue() -> (x: Int16, y: Int16, z: Int16) {
        let rawValues = readRegister(.OUT_X_L, count: 6)
        guard rawValues.count == 6 else { return (0, 0, 0) }
        let x = Int16(rawValues[0]) | (Int16(rawValues[1]) << 8)
        let y = Int16(rawValues[2]) | (Int16(rawValues[3]) << 8)
        let z = Int16(rawValues[4]) | (Int16(rawValues[5]) << 8)

        return (x, y, z)
    }

    public func readValue() -> (x: Float, y: Float, z: Float) {
        let (ix, iy, iz) = readRawValue()
        var value: (x: Float, y: Float, z: Float) = (Float(ix), Float(iy), Float(iz))

        value.x = value.x / gCoefficient
        value.y = value.y / gCoefficient
        value.z = value.z / gCoefficient

        return value
    }

    public func readX() -> Float {
        let rawValues = readRegister(.OUT_X_L, count: 2)
        guard rawValues.count == 2 else { return 0 }
        let ix = Int16(rawValues[0]) | (Int16(rawValues[1]) << 8)

        return Float(ix) / gCoefficient
    }

    public func readY() -> Float {
        let rawValues = readRegister(.OUT_Y_L, count: 2)
        guard rawValues.count == 2 else { return 0 }
        let iy = Int16(rawValues[0]) | (Int16(rawValues[1]) << 8)

        return Float(iy) / gCoefficient
    }

    public func readZ() -> Float {
        let rawValues = readRegister(.OUT_Z_L, count: 2)
        guard rawValues.count == 2 else { return 0 }
        let iz = Int16(rawValues[0]) | (Int16(rawValues[1]) << 8)

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
}