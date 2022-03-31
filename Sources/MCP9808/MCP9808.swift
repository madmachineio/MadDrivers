import SwiftIO

final public class MCP9808 {
    private let i2c: I2C
    private let address: UInt8

    private var readBuffer = [UInt8](repeating: 0, count: 2)

    public init(_ i2c: I2C, address: UInt8 = 0x18) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": MCP9808 only supports 100kHz (standard) and 400kHz (fast) I2C speed")
        }

        self.i2c = i2c
        self.address = address

        guard getId() == (0x0054, 0x04) else {
            fatalError(#function + ": Fail to find MCP9808 at address \(address)")
        }
    }

    public func readTemperature() -> Float {
        try? readRegister(.temperature, into: &readBuffer, count: 2)

        let rawValue = UInt16(readBuffer[0]) << 8 | UInt16(readBuffer[1])
        var temp = Float(rawValue & 0x0FFF) / 16

        if readBuffer[0] & 0x10 != 0 {
            temp -= 256
        }

        return temp
    }

    func getResolution() -> Resolution {
        var byte: UInt8 = 0
        try? readRegister(.resolution, into: &byte)

        return Resolution(rawValue: byte & 0x03)!
    }

    func setResolution(_ resolution: Resolution) {
        try? writeRegister(.resolution, resolution.rawValue)
    }

    func getId() -> (UInt16, UInt8) {
        try? readRegister(.manufacturerID, into: &readBuffer, count: 2)
        let manufacturerID = UInt16(readBuffer[0]) << 8 | UInt16(readBuffer[1])

        try? readRegister(.deviceID, into: &readBuffer, count: 2)
        let deviceID = readBuffer[0]

        return (manufacturerID, deviceID)
    }



    private func readRegister(
        _ register: Register, into buffer: inout [UInt8], count: Int
    ) throws {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        var result = i2c.write(register.rawValue, to: address)
        if case .failure(let err) = result {
            throw err
        }

        result = i2c.read(into: &buffer, count: count, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func readRegister(
        _ register: Register, into byte: inout UInt8
    ) throws {

        var result = i2c.write(register.rawValue, to: address)
        if case .failure(let err) = result {
            throw err
        }

        result = i2c.read(into: &byte, from: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func writeRegister(_ register: Register, _ value: UInt8) throws {
        let result = i2c.write([register.rawValue, value], to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    enum Register: UInt8 {
        case manufacturerID = 0x06
        case deviceID = 0x07
        case temperature = 0x05
        case resolution = 0x08
    }

    enum Resolution: UInt8 {
        // 0.5°C, 30ms reading time.
        case halfC = 0
        // 0.25°C, 65ms reading time.
        case quarterC = 1
        // 0.125°C, 130ms reading time.
        case eighthC = 2
        // 0.0625°C, 250ms reading time. The default resultion after power-up.
        case sixteenthC = 3
    }
}
