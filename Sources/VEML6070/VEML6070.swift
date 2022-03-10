import SwiftIO

final public class VEML6070 {
    private let i2c: I2C
    private var integrationTime: IntegrationTime = .t1
    private var ack: UInt8 = 0
    private var ackThreshold: UInt8 = 0

    public init(_ i2c: I2C) {
        self.i2c = i2c

        clearAck()
        setIntegrationTime(integrationTime)
    }

    public func readUVRaw() -> UInt16 {
        var msb: UInt8 = 0
        i2c.read(into: &msb, from: Address.msb.rawValue)

        var lsb: UInt8 = 0
        i2c.read(into: &lsb, from: Address.cmdLsb.rawValue)

        return UInt16(msb) << 8 | UInt16(lsb)
    }

    public func readUVIndex(_ rawUV: UInt16) -> UVIndex {
        var uv: UInt16 {
            switch integrationTime {
            case .tHalf:
                return rawUV * 2
            case .t1:
                return rawUV
            case .t2:
                return rawUV / 2
            case .t4:
                return rawUV / 4
            }
        }

        if uv <= 560 {
            return .low
        } else if uv <= 1120 {
            return .moderate
        } else if uv <= 1494 {
            return .high
        } else if uv <= 2054 {
            return .veryHigh
        } else {
            return .extreme
        }
    }

    /// <#Description#>
    /// - Parameters:
    ///   - enable: whether to enable the interrupt.
    ///   - threshold: the threshold for acknowledge signal. true for 145 and false for 102.
    public func setInterrupt(enable: Bool, threshold: Bool) {
        ack = enable ? 1 : 0
        ackThreshold = threshold ? 1 : 0
        let command = ack << 5 | ackThreshold << 4 | integrationTime.rawValue << 2 | 0x02
        try? writeCommand(command)
    }

    public func setIntegrationTime(_ time: IntegrationTime) {
        integrationTime = time
        let command = ack << 5 | ackThreshold << 4 | integrationTime.rawValue << 2 | 0x02
        try? writeCommand(command)
    }

    public func sleep() {
        try? writeCommand(0x03)
    }

    public func wake() {
        let command = ack << 5 | ackThreshold << 4 | integrationTime.rawValue << 2 | 0x02
        try? writeCommand(command)
    }


    public enum UVIndex {
        case low
        case moderate
        case high
        case veryHigh
        case extreme
    }

    public enum IntegrationTime: UInt8 {
        case tHalf = 0
        case t1 = 1
        case t2 = 2
        case t4 = 3
    }
}

extension VEML6070 {
    private enum Address: UInt8 {
        case cmdLsb = 0x38
        case msb = 0x39
        case ara = 0x0C
    }

    private func writeCommand(_ command: UInt8) throws {
        let result = i2c.write(command, to: Address.cmdLsb.rawValue)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func clearAck() {
        var byte: UInt8 = 0
        i2c.read(into: &byte, from: Address.ara.rawValue)
    }


}
