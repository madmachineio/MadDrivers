import SwiftIO
import Darwin

final public class SGP30 {
    private let i2c: I2C
    private let address: UInt8

    private var readBuffer = [UInt8](repeating: 0, count: 9)

    let polynomial: UInt8 = 0x31

    init(_ i2c: I2C, address: UInt8 = 0x58) {
        let speed = i2c.getSpeed()
        guard speed == .fast else {
            fatalError(#function + ": SGP30 only supports 400kHz (fast) I2C speed")
        }

        self.i2c = i2c
        self.address = address

        try? readCommand(.serial_id, into: &readBuffer, count: 3, delay: 10)
        guard getData(readBuffer, count: 3) != nil else {
            fatalError(#function + ": Fail to find SGP30 at address \(address)")
        }

        try? readCommand(.get_feature_set, into: &readBuffer, count: 1, delay: 10)
        guard getData(readBuffer, count: 1) == [0x0020]
                || getData(readBuffer, count: 1) == [0x0022] else {
            fatalError(#function + ": Fail to find SGP30 at address \(address)")
        }

        try? writeCommand(.iaq_init, delay: 10)

    }


    func readRaw() -> [UInt16] {
        try? readCommand(.measure_raw, into: &readBuffer, count: 2, delay: 25)
        let raw = getData(readBuffer, count: 2)
        if let raw = raw {
            return raw
        } else {
            return [0, 0]
        }
    }
    

    func getData(_ buffer: [UInt8], count: Int) -> [UInt16]? {
        var crc: UInt8 = 0
        var data: [UInt16] = []

        for i in 0..<count {
            let msb = buffer[i * 3]
            let lsb = buffer[i * 3 + 1]
            crc = buffer[i * 3 + 2]

            if calculateCRC([msb, lsb]) != crc {
                print(#function + ": CRC error!")
                return nil
            }

            data.append(UInt16(msb) << 8 | UInt16(lsb))
        }

        return data
    }

    func writeCommand(_ command: Command, delay: Int) throws {
        let result = i2c.write([UInt8(command.rawValue >> 8), UInt8(command.rawValue & 0xFF)], to: address)
        if case .failure(let err) = result {
            throw err
        }


        sleep(ms: delay)
    }



    func readCommand(_ command: Command, into buffer: inout [UInt8], count: Int, delay: Int) throws {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }
        var result = i2c.write([UInt8(command.rawValue >> 8), UInt8(command.rawValue & 0xFF)], to: address)

        if case .failure(let err) = result {
            throw err
        }

        sleep(ms: delay)

        result = i2c.read(into: &buffer, count: count * 3, from: address)

        if case .failure(let err) = result {
            throw err
        }
    }

    func calculateCRC(_ data: [UInt8]) -> UInt8 {
        var crc: UInt8 = 0xFF

        for byte in data {
            crc ^= byte

            for _ in 0..<8 {
                if crc & 0x80 != 0 {
                    crc = (crc << 1) ^ polynomial
                } else {
                    crc = crc << 1
                }
            }
        }

        return crc
    }



    enum Command: UInt16 {
        case iaq_init = 0x2003
        case measure_iaq = 0x2008
        case get_iaq_baseline = 0x15
        case set_iaq_baseline = 0x201E
        case set_absolute_humidity = 0x2061
        case measure_raw = 0x2050
        case serial_id = 0x3682
        case get_feature_set = 0x202F

    }
}
