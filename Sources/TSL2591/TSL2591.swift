import SwiftIO

final public class TSL2591 {
    private let i2c: I2C
    private let address: UInt8

    private var commandBit: UInt8 = 0xA0

    private var gain: Gain

    private var aGain: Float {
        switch gain {
        case .low:
            return 1
        case .medium:
            return 25
        case .high:
            return 428
        case .maximum:
            return 9876
        }
    }

    private var readBuffer = [UInt8](repeating: 0, count: 2)

    public init(_ i2c: I2C, address: UInt8 = 0x29) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": TSL2591 only supports 100kHz (standard) and 400kHz (fast) I2C speed")
        }

        self.i2c = i2c
        self.address = address

        gain = .medium

        guard getDeviceID() == 0x50 else {
            fatalError(#function + ": Fail to find TSL2591 at address \(address)")
        }

        setGain(gain)


        enable()
    }



    public func readIR() -> UInt16 {
        return readRaw().1
    }

    public func readFullSpectrum() -> UInt32 {
        let value = readRaw()
        return UInt32(value.1) << 16 | UInt32(value.0)
    }

    public func readVisible() -> UInt32 {
        let value = readRaw()
        return UInt32(value.1) << 16 | UInt32(value.0) - UInt32(value.1)
    }

    /// Power on and enable No Persist Interrupt, ALS Interrupt, ALS.
    func enable() {
        try? writeRegister(.enable, 0b10010011)
    }


    func setGain(_ gain: Gain) {
        self.gain = gain

        var control: UInt8 = 0
        try? readRegister(.control, into: &control)

        control = control & 0b11001111 | (gain.rawValue << 4)
        try? writeRegister(.control, control)
    }

    func getGain() -> Gain {
        var control: UInt8 = 0
        try? readRegister(.control, into: &control)

        gain = Gain(rawValue: (control & 0b00110000) >> 4)!
        return gain
    }

    enum Gain: UInt8 {
        /// x1
        case low = 0
        /// x25
        case medium = 1
        /// x428
        case high = 2
        /// x9876
        case maximum = 3
    }
}

extension TSL2591 {
    enum Register: UInt8 {
        case enable = 0x00
        case control = 0x01
        case deviceID = 0x12
        case C0DATAL = 0x14
        case C1DATAL = 0x16
    }

    private func readRegister(
        _ register: Register, into byte: inout UInt8
    ) throws {
        var result = i2c.write(register.rawValue | commandBit, to: address)
        if case .failure(let err) = result {
            throw err
        }

        result = i2c.read(into: &byte, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func readRegister(
        _ register: Register, into buffer: inout [UInt8], count: Int
    ) throws {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        var result = i2c.write(register.rawValue | commandBit, to: address)
        if case .failure(let err) = result {
            throw err
        }

        result = i2c.read(into: &buffer, count: count, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func writeRegister(_ reg: Register, _ value: UInt8) throws {
        let result = i2c.write([reg.rawValue | commandBit, value], to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func getDeviceID() -> UInt8 {
        var byte: UInt8 = 0
        try? readRegister(.deviceID, into: &byte)
        return byte
    }

    func readRaw() -> (UInt16, UInt16) {
        try? readRegister(.C0DATAL, into: &readBuffer, count: 2)
        let channel0 = UInt16(readBuffer[1]) << 8 | UInt16(readBuffer[0])

        try? readRegister(.C1DATAL, into: &readBuffer, count: 2)
        let channel1 = UInt16(readBuffer[1]) << 8 | UInt16(readBuffer[0])
        return (channel0, channel1)
    }
}
