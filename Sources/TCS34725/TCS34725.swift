
import SwiftIO

final public class TCS34725 {
    private let i2c: I2C
    private let address: UInt8

    private let commandBit: UInt8 = 0x80

    private var integrationTime: Float
    private var glassAttenuation: Float = 1

    private var readBuffer = [UInt8](repeating: 0, count: 2)

    public init(_ i2c: I2C, address: UInt8 = 0x29) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": TCS34725 only supports 100kHz (standard) and 400kHz (fast) I2C speed")
        }

        self.i2c = i2c
        self.address = address

        integrationTime = 2.4

        guard getID() == 0x44 || getID() == 0x10 else {
            fatalError(#function + ": Fail to find TCS34725 at address \(address)")
        }

        setIntegrationTime(Int(integrationTime / 2.4))
        
    }

    func readRaw() -> (r: UInt16, g: UInt16, b: UInt16, c: UInt16) {
        enable()

        var status: UInt8 = 0
        repeat {
            try? readRegister(.status, into: &status)
        } while status & 0x01 == 0

        try? readRegister(.rDataL, into: &readBuffer, count: 2)
        let red = UInt16(readBuffer[0]) | UInt16(readBuffer[1]) << 8

        try? readRegister(.gDataL, into: &readBuffer, count: 2)
        let green = UInt16(readBuffer[0]) | UInt16(readBuffer[1]) << 8

        try? readRegister(.bDataL, into: &readBuffer, count: 2)
        let blue = UInt16(readBuffer[0]) | UInt16(readBuffer[1]) << 8

        try? readRegister(.cDataL, into: &readBuffer, count: 2)
        let clear = UInt16(readBuffer[0]) | UInt16(readBuffer[1]) << 8

        disable()

        return (red, green, blue, clear)
    }



    /// The integration equals the count of cycles * 2.4 milliseconds.
    /// The cycles are from 1 to 256.
    /// The max raw values equals (256 - cycles) * 1024, but 65535 at most.
    func setIntegrationTime(_ cycles: Int) {
        guard cycles <= 256 && cycles >= 1 else {
            print(#function + ": The cycle should be from 1 to 256.")
            return
        }

        integrationTime = Float(cycles) * 2.4
        try? writeRegister(.aTime, UInt8(256 - cycles))
    }

    func getID() -> UInt8 {
        var byte: UInt8 = 0
        try? readRegister(.id, into: &byte)
        return byte
    }

    func setGlassAttenuation(_ factor: Float) {
        glassAttenuation = factor
    }

    func enable() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)

        try? writeRegister(.enable, byte | Enable.powerOn.rawValue)
        sleep(ms: 3)
        try? writeRegister(.enable, byte | Enable.enable.rawValue)
    }

    func disable() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)

        try? writeRegister(.enable, byte & ~Enable.enable.rawValue)
    }

    struct Enable: OptionSet {
        let rawValue: UInt8

        static let PON = Enable(rawValue: 1)
        static let AEN = Enable(rawValue: 1 << 1)
        static let WEN = Enable(rawValue: 1 << 3)
        static let AIEN = Enable(rawValue: 1 << 4)

        static let powerOn = Enable([.PON])
        static let enable = Enable([.AEN, .PON])
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

    private func writeRegister(_ register: Register, _ value: UInt8) throws {
        let result = i2c.write([register.rawValue | commandBit, value], to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func writeRegister(_ register: Register, _ data: [UInt8]) throws {
        var data = data
        data.insert(register.rawValue | commandBit, at: 0)
        let result = i2c.write(data, to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    enum Register: UInt8 {
        case id = 0x12
        case enable = 0x00
        case aTime = 0x01
        case cDataL = 0x14
        case rDataL = 0x16
        case gDataL = 0x18
        case bDataL = 0x1A
        case status = 0x13
    }
    
}
