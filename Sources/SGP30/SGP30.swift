import SwiftIO
import RealModule

final public class SGP30 {
    private let i2c: I2C
    private let address: UInt8

    private var readBuffer = [UInt8](repeating: 0, count: 9)

    private let polynomial: UInt8 = 0x31

    /// Initialize the sensor using I2C communication.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   - address: **OPTIONAL** The sensor's address, 0x58 by default.
    public init(_ i2c: I2C, address: UInt8 = 0x58) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": SGP30 only supports 100kHz (standard) and 400kHz (fast) I2C speed")
        }

        self.i2c = i2c
        self.address = address

        try? readRegister(.serial_id, into: &readBuffer, count: 3, delay: 10)
        guard getData(readBuffer, count: 3) != [0, 0, 0] else {
            fatalError(#function + ": Fail to find SGP30 at address \(address)")
        }

        try? readRegister(.get_feature_set, into: &readBuffer, count: 1, delay: 10)
        guard getData(readBuffer, count: 1) == [0x0020]
                || getData(readBuffer, count: 1) == [0x0022] else {
                    fatalError(#function + ": Fail to find SGP30 at address \(address)")
                }

        try? writeValue(.iaq_init, delay: 10)

    }

    /// Read Indoor Air Quality (IAQ) .
    /// - Returns:
    public func readIAQ() -> (eCO2: UInt16, TVOC: UInt16) {
        try? readRegister(.measure_iaq, into: &readBuffer, count: 2, delay: 50)
        let iaq = getData(readBuffer, count: 2)
        return (iaq[0], iaq[1])
    }

    public func readECO2() -> UInt16 {
        return readIAQ().eCO2
    }

    public func readTVOC() -> UInt16 {
        return readIAQ().TVOC
    }


    public func readRaw() -> (H2: UInt16, Ethanol: UInt16) {
        try? readRegister(.measure_raw, into: &readBuffer, count: 2, delay: 25)
        let raw = getData(readBuffer, count: 2)
        return (raw[0], raw[1])
    }

    public func readH2() -> UInt16 {
        return readRaw().H2
    }

    public func readEthanol() -> UInt16 {
        return readRaw().Ethanol
    }


    public func getBaseline() -> (eCO2: UInt16, TVOC: UInt16) {
        try? readRegister(.get_iaq_baseline, into: &readBuffer, count: 2, delay: 10)
        let baseline = getData(readBuffer, count: 2)
        return (baseline[0], baseline[1])
    }

    public func getECO2() -> UInt16 {
        return getBaseline().eCO2
    }

    public func getTVOCBaseline() -> UInt16 {
        return getBaseline().TVOC
    }

    public func setBaseline(eCO2: UInt16, TVOC: UInt16) {
        guard eCO2 > 0 && TVOC > 0 else {
            return
        }

        var data: [UInt8] = []

        for value in [TVOC, eCO2] {
            let bytes = calUInt16ToUInt8(value)
            data += bytes
            data.append(calculateCRC(bytes))
        }

        try? writeRegister(.set_iaq_baseline, data: data, delay: 10)
    }


    /// Set the absolute humidity compensation in g/m3 for measurement.
    /// - Parameter humidity: Absolute humidity in g/m3.
    public func setAbsoluteHumidity(_ humidity: Float) {

        var data = calUInt16ToUInt8(UInt16(Int(humidity * 256) & 0xFFFF))
        data.append(calculateCRC(data))

        try? writeRegister(.set_absolute_humidity, data: data, delay: 10)
    }


    /// Set the humidity comenpansation using temperature and relative humidity.
    /// - Parameters:
    ///   - celcius: Current temperature in celcius.
    ///   - humidity: Current relative humidity.
    public func setRelativeHumidity(celcius: Float, humidity: Float) {
        let numerator = humidity / 100 * 6.112 * Float.exp((17.62 * celcius) / (243.12 + celcius))

        let denominator = 273.15 + celcius

        let absoluteHumi = 216.7 * (numerator / denominator)
        setAbsoluteHumidity(absoluteHumi)
    }

}


extension SGP30 {
    enum Command: UInt16 {
        case iaq_init = 0x2003
        case measure_iaq = 0x2008
        case get_iaq_baseline = 0x2015
        case set_iaq_baseline = 0x201E
        case set_absolute_humidity = 0x2061
        case measure_raw = 0x2050
        case serial_id = 0x3682
        case get_feature_set = 0x202F

    }

    func writeValue(_ command: Command, delay: Int) throws {
        let result = i2c.write(calUInt16ToUInt8(command.rawValue), to: address)
        if case .failure(let err) = result {
            throw err
        }

        sleep(ms: delay)
    }

    func writeRegister(_ command: Command, data: [UInt8], delay: Int) throws {
        let data = calUInt16ToUInt8(command.rawValue) + data

        let result = i2c.write(data, to: address)
        if case .failure(let err) = result {
            throw err
        }

        sleep(ms: delay)
    }


    func readRegister(
        _ command: Command, into buffer: inout [UInt8],
        count: Int, delay: Int) throws {
            
            for i in 0..<buffer.count {
                buffer[i] = 0
            }
            var result = i2c.write(calUInt16ToUInt8(command.rawValue), to: address)

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

    func calUInt16ToUInt8(_ value: UInt16) -> [UInt8] {
        return [UInt8(value >> 8), UInt8(value & 0xFF)]
    }

    func getData(_ buffer: [UInt8], count: Int) -> [UInt16] {
        var crc: UInt8 = 0
        var data: [UInt16] = []

        for i in 0..<count {
            let msb = buffer[i * 3]
            let lsb = buffer[i * 3 + 1]
            crc = buffer[i * 3 + 2]

            if calculateCRC([msb, lsb]) != crc {
                print(#function + ": CRC error!")
                return [UInt16](repeating: 0, count: count)
            }

            data.append(UInt16(msb) << 8 | UInt16(lsb))
        }

        return data
    }

}
