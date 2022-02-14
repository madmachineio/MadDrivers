import SwiftIO

final public class VL53L0x {
    public let i2c: I2C
    public let address: UInt8

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
        try? readRegister(.MSRC_CONFIG_CONTROL, into: &byte)
        try? writeRegister(.MSRC_CONFIG_CONTROL, byte | 0x12)

        setSignalRateLimit(0.25)

        try? writeRegister(.SYSTEM_SEQUENCE_CONFIG, 0xFF)





    }


    // SPAD (single photon avalanche diode)
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
