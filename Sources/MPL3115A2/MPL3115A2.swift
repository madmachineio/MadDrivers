
import SwiftIO

/// This is the library for MPL3115A2 pressure sensor. It supports I2C communication.
///
/// The sensor can measure a wide range of pressure from 20 kPa to 110 kPa
/// and temperature from −40 °C to 85 °C. The temperature and pressure readings
/// will finally be compensated and turned into pressure in Pascals and temperature
/// in °C. The altitude is calculated with the pressure data and sea level pressure.
/// So to ensure a more accurate altitude, you can update the current sea level pressure at your location.
final public class MPL3115A2 {
    private let i2c: I2C
    private let address: UInt8
    private var readBuffer = [UInt8](repeating: 0, count: 3)

    /// Initialize the sensor using I2C communication.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   - address: **OPTIONAL** The device address of the sensor, 0x60 by default.
    public init(_ i2c: I2C, address: UInt8 = 0x60) {
        self.i2c = i2c
        self.address = address

        guard getDeviceID() == 0xC4 else {
            fatalError(#function + ": Fail to find MPL3115A2 at address \(address)")
        }

        reset()
        configure()
    }

    /// Read the current pressure in Pascals (Pa).
    /// - Returns: The pressure in Pa.
    public func readPressure() -> Float {
        poll()
        setMode(.pressure)
        waitData()

        try? readRegister(.OUT_P_MSB, into: &readBuffer, count: 3)
        let pressure = (UInt32(readBuffer[0]) << 16 | UInt32(readBuffer[1]) << 8 | UInt32(readBuffer[2])) >> 4

        return Float(pressure) / 4
    }

    /// Read the altitude in meters.
    ///
    /// It is calculated based on current pressure and sea level pressure.
    /// To get a more accurate reading, you can update the sea level pressure
    /// using ``setSeaLevelPressure(_:)``.
    /// - Returns: The altitude in meters.
    public func readAltitude() -> Float {
        poll()
        setMode(.altimeter)
        waitData()
        try? readRegister(.OUT_P_MSB, into: &readBuffer, count: 3)

        let data = Int32(readBuffer[0]) << 24 | Int32(readBuffer[1]) << 16 | Int32(readBuffer[2]) << 8
        return Float(data) / 65535
    }

    /// Read the current temperature in Celsius.
    /// - Returns: The temperature in Celsius.
    public func readTemperature() -> Float {
        var status: UInt8 = 0
        try? readRegister(.STATUS, into: &status)
        while status & 0b10 == 0 {
            sleep(ms: 10)
            try? readRegister(.STATUS, into: &status)
        }

        try? readRegister(.OUT_T_MSB, into: &readBuffer, count: 2)
        let temp = (Int16(readBuffer[0]) << 8 | Int16(readBuffer[1])) >> 4
        return Float(temp) / 16

    }

    /// Get the current sea level pressure used to calculate the altitude.
    /// - Returns: The sea level pressure in Pa.
    public func getSeaLevelPressure() -> Int {
        try? readRegister(.BAR_IN_MSB, into: &readBuffer, count: 2)
        return Int(UInt16(readBuffer[0]) << 8 | UInt16(readBuffer[1])) * 2
    }



    /// Set the current sea level pressure used to calculate the altitude.
    ///
    /// The default setting of the sensor is 101,326 Pa.
    /// You can find the current sea level pressure [here](https://weather.us/observations/pressure-qff.html).
    /// - Parameter pressure: The sea level pressure in Pa.
    public func setSeaLevelPressure(_ pressure: Int) {
        let value = UInt16(pressure / 2)
        let data = [UInt8(value >> 8), UInt8(value & 0xFF)]
        try? writeRegister(.BAR_IN_MSB, data)
    }


    /// Set the mode of the sensor to measure altitude or pressure.
    func setMode(_ mode: Mode) {
        var control: UInt8 = 0
        try? readControlReg(into: &control)

        if mode == .pressure {
            control &= ~CtrlReg1.ALT.rawValue
        } else {
            control |= CtrlReg1.ALT.rawValue
        }

        try? writeControlReg(control)
    }

    enum Mode {
        case pressure
        case altimeter
    }


    func setOversample(_ oversample: Oversample) {
        var control: UInt8 = 0
        try? readControlReg(into: &control)
        try? writeControlReg(control & 0b1100_0111 | oversample.rawValue << 3)
    }

    enum Oversample: UInt8 {
        case ratio1 = 0
        case ratio2 = 1
        case ratio4 = 2
        case ratio8 = 3
        case ratio16 = 4
        case ratio32 = 5
        case ratio64 = 6
        case ratio128 = 7
    }

}


extension MPL3115A2 {
    enum Register: UInt8 {
        case STATUS = 0x00
        case OUT_P_MSB = 0x01
        case OUT_T_MSB = 0x04
        case WHO_AM_I = 0x0C
        case PT_DATA_CFG = 0x13
        case BAR_IN_MSB = 0x14
        case CTRL_REG1 = 0x26
    }

    enum CtrlReg1: UInt8 {
        case SBYB = 0b1
        case OST = 0b10
        case RST = 0b100
        case ALT = 0b1000_0000
    }


    private func readRegister(
        _ register: Register, into buffer: inout [UInt8], count: Int
    ) throws {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        let result = i2c.writeRead(register.rawValue, into: &buffer, readCount: count, address: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func readRegister(
        _ register: Register, into byte: inout UInt8
    ) throws {
        let result = i2c.writeRead(register.rawValue, into: &byte, address: address)
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

    private func writeRegister(_ register: Register, _ data: [UInt8]) throws {
        var data = data
        data.insert(register.rawValue, at: 0)
        let result = i2c.write(data, to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    func writeControlReg(_ value: UInt8) throws {
        try writeRegister(.CTRL_REG1, value)
    }

    func readControlReg(into byte: inout UInt8) throws {
        try readRegister(.CTRL_REG1, into: &byte)
    }

    func getDeviceID() -> UInt8 {
        var id: UInt8 = 0
        try? readRegister(.WHO_AM_I, into: &id)
        return id
    }

    func reset() {
        try? writeControlReg(CtrlReg1.RST.rawValue)

        var control: UInt8 = 0
        repeat {
            sleep(ms: 10)
            try? readControlReg(into: &control)
        }  while control & 0b100 != 0

    }

    /// Set oversample ratio and set the sensor to altitude mode.
    func configure() {
        setOversample(.ratio128)
        setMode(.altimeter)

        try? writeRegister(.PT_DATA_CFG, 0b111)
    }

    func poll() {
        var byte: UInt8 = 0
        try? readControlReg(into: &byte)
        while byte & 0b10 != 0 {
            sleep(ms: 10)
            try? readControlReg(into: &byte)
        }
    }

    func waitData() {
        /// Start measurement.
        var control: UInt8 = 0
        try? readControlReg(into: &control)
        try? writeControlReg(control | 0b0010)

        /// Check if data is available.
        var status: UInt8 = 0
        try? readRegister(.STATUS, into: &status)
        while status & 0b100 == 0 {
            sleep(ms: 10)
            try? readRegister(.STATUS, into: &status)
        }
    }


}
