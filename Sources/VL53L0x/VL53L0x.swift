import SwiftIO

final public class VL53L0x {
    public let i2c: I2C
    public let address: UInt8
    public let ioTimeout: Int
    private var readBuffer = [UInt8](repeating: 0, count: 6)
    var timingBudget: UInt32 = 0

    public init(_ i2c: I2C, address: UInt8 = 0x29, ioTimeout: Int = 0) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": VL53L0x only supports 100kHz (standard) and 400kHz (fast) I2C speed")
        }

        self.i2c = i2c
        self.address = address
        self.ioTimeout = ioTimeout

        var byte: UInt8 = 0
        try? readRegister(.IDENTIFICATION_MODEL_ID, into: &byte)
        guard byte == 0xEE else {
            fatalError(#function + ": Fail to find VL53L0x at address \(address)")
        }

        dataInit()
        staticInit()
        performRefCalibration()
    }

    /// Set the measurement timing budget in microsecond.
    ///
    /// It is the maximum time for one measurement. A longer timing budget allows for
    /// more accurate measurements.
    /// - Parameter budget: maximum measurement time in microsecond.
    /// It should be bigger than 17000us.
    func setMeasurementTimingBudget(_ budget: UInt32) {
        guard budget <= 20000 else { return }

        var sumBudget = 1320 + OverheadUs.end.rawValue
        let enables = getSequenceStepEnables()
        let timeouts = getSequenceStepTimeouts(enables.preRange)

        if enables.tcc {
            sumBudget += timeouts.msrcDssTccUs + OverheadUs.tcc.rawValue
        }

        if enables.dss {
            sumBudget += 2 * (timeouts.msrcDssTccUs + OverheadUs.dss.rawValue)
        } else if enables.msrc {
            sumBudget += timeouts.msrcDssTccUs + OverheadUs.msrcPreRange.rawValue
        }

        if enables.preRange {
            sumBudget += timeouts.preRangeUs + OverheadUs.msrcPreRange.rawValue
        }

        if enables.finalRange {
            sumBudget += OverheadUs.finalRange.rawValue

            if sumBudget > budget {
                print(#function + ": the timing budget needs to be bigger")
                return
            }

            let finalRangeTimeout = budget - sumBudget
            var finalRangeTimeoutMclks = calTimeoutMclks(finalRangeTimeout, timeouts.finalRangePclks)

            if enables.preRange {
                finalRangeTimeoutMclks += UInt32(timeouts.preRangeMclks)
            }

            let data = encodeTimeout(finalRangeTimeoutMclks)
            try? writeRegister(.FINAL_RANGE_CONFIG_TIMEOUT_MACROP_HI, data)

            timingBudget = budget
        }
    }

    /// Get the measurement timing budget in microseconds.
    func getMeasurementTimingBudget() -> UInt32 {
        var budget: UInt32 = OverheadUs.start.rawValue + OverheadUs.end.rawValue
        let enables = getSequenceStepEnables()
        let timeouts = getSequenceStepTimeouts(enables.preRange)

        if enables.tcc {
            budget += timeouts.msrcDssTccUs + OverheadUs.tcc.rawValue
        }

        if enables.dss {
            budget += 2 * (timeouts.msrcDssTccUs + OverheadUs.dss.rawValue)
        } else if enables.msrc {
            budget += timeouts.msrcDssTccUs + OverheadUs.msrcPreRange.rawValue
        }

        if enables.preRange {
            budget += timeouts.preRangeUs + OverheadUs.msrcPreRange.rawValue
        }

        if enables.finalRange {
            budget += timeouts.finalRangeUs + OverheadUs.finalRange.rawValue
        }

        return budget
    }

    /// Get the VCSEL pulse period in PCLKs with the specified period type.
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

    /// Set the return signal rate limit in mega counts per second.
    /// It decides the minimum measurement for a valid reading.
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
        case MSRC_CONFIG_TIMEOUT_MACROP = 0x46
        case PRE_RANGE_CONFIG_TIMEOUT_MACROP_HI = 0x51
        case FINAL_RANGE_CONFIG_TIMEOUT_MACROP_HI = 0x71
        case SYSRANGE_START = 0x00
        case RESULT_INTERRUPT_STATUS = 0x13
    }

    enum OverheadUs: UInt32 {
        case start = 1910
        case end = 960
        case msrcPreRange = 660
        case tcc = 590
        case dss = 690
        case finalRange = 550
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
        timingBudget = getMeasurementTimingBudget()

        // Disable msrc (Minimum Signal Rate Check) and tcc (Target Centre Check).
        try? writeRegister(.SYSTEM_SEQUENCE_CONFIG, 0xE8)

        setMeasurementTimingBudget(timingBudget)
    }

    func performRefCalibration() {
        // Perform vhv calibration.
        try? writeRegister(.SYSTEM_SEQUENCE_CONFIG, 0x01)
        performSingleRefCalibration(0x40)

        // Perform phase calibration.
        try? writeRegister(.SYSTEM_SEQUENCE_CONFIG, 0x02)
        performSingleRefCalibration(0x00)

        try? writeRegister(.SYSTEM_SEQUENCE_CONFIG, 0xE8)
    }

    func performSingleRefCalibration(_ vhvInitByte: UInt8) {
        try? writeRegister(.SYSRANGE_START, 0x01 | vhvInitByte)
        let start = getSystemUptimeInMilliseconds()

        var byte: UInt8 = 0
        repeat {
            try? readRegister(.RESULT_INTERRUPT_STATUS, into: &byte)

            if ioTimeout > 0 && getSystemUptimeInMilliseconds() - start >= ioTimeout {
                print(#function + ": Timeout waiting for VL53L0X.")
            }
        } while byte & 0x07 == 0

        try? writeRegister(.SYSTEM_INTERRUPT_CLEAR, 0x01)
        try? writeRegister(.SYSRANGE_START, 0x00)
    }

    func calTimeoutUs(_ timeoutMclkd: UInt16, _ vcselPclks: UInt8) -> UInt32 {
        let macroPeriodns = (2304 * UInt32(vcselPclks) * 1655 + 500) / 1000
        return (UInt32(timeoutMclkd) * macroPeriodns + 500) / 1000
    }

    func calTimeoutMclks(_ timeoutUs: UInt32, _ vcselPclks: UInt8) -> UInt32 {
        let macroPeriodns = (2304 * UInt32(vcselPclks) * 1655 + 500) / 1000
        return (timeoutUs * 1000 + macroPeriodns / 2) / macroPeriodns
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
        guard spadInfo != nil else {
            print(#function + ": Failt to get spad info")
            return
        }

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
    func getSpadInfo() -> (UInt8, Bool)? {
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

        repeat {
            try? readRegister(0x83, into: &byte)
            if ioTimeout > 0 && getSystemUptimeInMilliseconds() - start > ioTimeout {
                return nil
            }
        } while byte == 0

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

    func decodeTimeout(msb: UInt8, lsb: UInt8) -> UInt16 {
        return (UInt16(lsb) << msb) + 1
    }

    func encodeTimeout(_ timeout: UInt32) -> [UInt8] {
        var lsb: UInt32 = 0
        var msb: UInt16 = 0

        if (timeout > 0) {
            lsb = timeout - 1

            while (lsb & 0xFFFFFF00) > 0 {
                lsb = lsb >> 1
                msb += 1
            }
        }

        return [UInt8(msb), UInt8(lsb)]
    }

    func getSequenceStepEnables() -> (tcc: Bool, dss: Bool, msrc: Bool, preRange: Bool, finalRange: Bool){
        var byte: UInt8 = 0
        try? readRegister(.SYSTEM_SEQUENCE_CONFIG, into: &byte)
        let tcc          = (byte >> 4) & 0x1 == 0x01
        let dss          = (byte >> 3) & 0x1 == 0x01
        let msrc         = (byte >> 2) & 0x1 == 0x01
        let preRange    = (byte >> 6) & 0x1 == 0x01
        let finalRange  = (byte >> 7) & 0x1 == 0x01
        return (tcc: tcc, dss: dss, msrc: msrc, preRange: preRange, finalRange: finalRange)
    }


    func getSequenceStepTimeouts(_ preRange: Bool) -> (msrcDssTccUs: UInt32, preRangeMclks: UInt16, preRangeUs: UInt32, finalRangePclks: UInt8, finalRangeUs: UInt32) {
        let preRangePclks = getVcselPulsePeriod(.preRange)

        var byte: UInt8 = 0
        try? readRegister(.MSRC_CONFIG_TIMEOUT_MACROP, into: &byte)
        let msrcDssTccMclks = UInt16(byte) + 1
        let msrcDssTccUs = calTimeoutUs(msrcDssTccMclks, preRangePclks)

        try? readRegister(.PRE_RANGE_CONFIG_TIMEOUT_MACROP_HI, into: &readBuffer, count: 2)
        let preRangeMclks = decodeTimeout(msb: readBuffer[0], lsb: readBuffer[1])

        let preRangeUs = calTimeoutUs(preRangeMclks, preRangePclks)

        let finalRangePclks = getVcselPulsePeriod(.finalRange)

        try? readRegister(.FINAL_RANGE_CONFIG_TIMEOUT_MACROP_HI, into: &readBuffer, count: 2)
        var finalRangeMclks = decodeTimeout(msb: readBuffer[0], lsb: readBuffer[1])

        if preRange {
            finalRangeMclks -= preRangeMclks
        }

        let finalRangeUs = calTimeoutUs(finalRangeMclks, finalRangePclks)

        return (msrcDssTccUs: msrcDssTccUs, preRangeMclks: preRangeMclks, preRangeUs: preRangeUs, finalRangePclks: finalRangePclks, finalRangeUs: finalRangeUs)
    }




}
