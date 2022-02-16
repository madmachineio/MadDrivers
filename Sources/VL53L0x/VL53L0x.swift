import SwiftIO

final public class VL53L0x {
    public let i2c: I2C
    public let address: UInt8
    private var readBuffer = [UInt8](repeating: 0, count: 6)

    init(_ i2c: I2C, address: UInt8 = 0x29) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": VL53L0x only supports 100kHz (standard) and 400kHz (fast) I2C speed")
        }

        self.i2c = i2c
        self.address = address

        var byte: UInt8 = 0
        try? readRegister(.IDENTIFICATION_MODEL_ID, into: &byte)

        guard byte == 0xEE else {
            fatalError(#function + ": Fail to find VL53L0x at address \(address)")
        }

        dataInit()




    }

    func dataInit() {
        // Set I2C standard mode.
        try? writeRegister(0x88, 0x00)

        try? writeRegister(0x80, 0x01)
        try? writeRegister(0xFF, 0x01)
        try? writeRegister(0x00, 0x00)

        try? writeRegister(0x00, 0x01)
        try? writeRegister(0xFF, 0x00)
        try? writeRegister(0x80, 0x00)

        // MSRC (Minimum Signal Rate Check).
        // Disable SIGNAL_RATE_MSRC (bit 1) and SIGNAL_RATE_PRE_RANGE (bit 4) limit checks
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


    }

    func getMeasurementTimingBudget() {
        
    }

    func getSequenceStepEnables() -> [Bool] {
        var byte: UInt8 = 0
        try? readRegister(.SYSTEM_SEQUENCE_CONFIG, into: &byte)
        let tcc          = (byte >> 4) & 0x1 == 0x01
        let dss          = (byte >> 3) & 0x1 == 0x01
        let msrc         = (byte >> 2) & 0x1 == 0x01
        let preRange    = (byte >> 6) & 0x1 == 0x01
        let finalRange  = (byte >> 7) & 0x1 == 0x01
        return [tcc, dss, msrc, preRange, finalRange]
    }


    func getSequenceStepTimeouts(_ preRange: Bool) -> [UInt16] {

        
    }


    func calTimeoutUs(_ timeoutMclkd: UInt16, _ vcselPclks: UInt8) -> UInt32 {
        let macroPeriodns = (2304 * UInt32(vcselPclks) * 1655 + 500) / 1000
        return (UInt32(timeoutMclkd) * macroPeriodns + 500) / 1000
    }


    func getVcselPulsePeriod(_ type: VcselPeriodType) -> UInt8 {
        var byte: UInt8 = 0
        if type == .preRange {
            try? readRegister(.PRE_RANGE_CONFIG_VCSEL_PERIOD, into: &byte)
        } else {
            try? readRegister(.FINAL_RANGE_CONFIG_VCSEL_PERIOD, into: &byte)
        }

        return (byte + 1) << 1
    }

    enum VcselPeriodType {
        case preRange
        case finalRange
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
        guard spadInfo != nil else { fatalError(#function + ": Failt to get spad info") }

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



    // Get reference SPAD (single photon avalanche diode) count and type.
    func getSpadInfo(timeout: UInt8 = 0) -> (UInt8, Bool)? {
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

        try? readRegister(0x83, into: &byte)
        while byte == 0 {
            try? readRegister(0x83, into: &byte)

            if timeout > 0 && getSystemUptimeInMilliseconds() - start > timeout {
                return nil
            }
        }

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

    // Set the return signal rate limit in mega counts per second.
    // It decides the minimum measurement for a valid reading.
    func setSignalRateLimit(_ limit: Float) {
        guard limit >= 0 && limit <= 511.99 else {
            print("signal rate limit should be within 0 - 511.00")
            return
        }

        let value = UInt16(limit * Float(1 << 7))
        let data = [UInt8(value >> 8), UInt8(value & 0xFF)]

        try? writeRegister(.FINAL_RANGE_CONFIG_MIN_COUNT_RATE_RTN_LIMIT, data)
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
}
