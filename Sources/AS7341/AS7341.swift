
import SwiftIO

final public class AS7341 {
    private let i2c: I2C
    private let address: UInt8

    init(_ i2c: I2C, address: UInt8 = 0x39) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": AS7341 only supports 100kHz (standard) and 400kHz (fast) I2C speed")
        }

        self.i2c = i2c
        self.address = address

        guard getID() == 0b00100100 else {
            fatalError(#function + ": Fail to find AS7341 at address \(address)")
        }

        powerOn()
        enableLEDControl()

        setAtime(100)
        setAstep(999)
        setGain(.x128)

    }

    /// Set sensor multiplexer (SMUX) for sensors F1 to F4, clear and NIR to map
    /// them into 6 internal ADCs.
    func setSmuxF1F4() {
        /// F3 left set to ADC2
        setSmux(.NC_CL, .disable, .adc2)

        
    }


    func setSmux(_ smuxIn: SmuxIn, _ smuxOut1: SmuxOut, _ smuxOut2: SmuxOut) {
        try? writeRegister(smuxIn.rawValue, UInt8(smuxOut1.rawValue) | UInt8(smuxOut2.rawValue << 4))
    }

    enum SmuxOut: UInt8 {
        case disable = 0
        case adc0 = 1
        case adc1 = 2
        case adc2 = 3
        case adc3 = 4
        case adc4 = 5
        case adc5 = 6
    }

    enum SmuxIn: UInt8 {
        case NC_F3L         = 0
        case F1L_NC         = 1
        case NC_NC0         = 2
        case NC_F8L         = 3
        case F6L_NC         = 4
        case F2L_F4L        = 5
        case NC_F5L         = 6
        case F7L_NC         = 7
        case NC_CL          = 8
        case NC_F5R         = 9
        case F7R_NC         = 10
        case NC_NC1         = 11
        case NC_F2R         = 12
        case F4R_NC         = 13
        case F8R_F6R        = 14
        case NC_F3R         = 15
        case F1R_EXT_GPIO   = 16
        case EXT_INT_CR     = 17
        case NC_DARK        = 18
        case NIR_F          = 19
    }



    func setAstep(_ step: UInt16) {
        try? writeRegister(.astepLSB, [UInt8(step & 0xFF), UInt8(step >> 8)])
    }

    func setAtime(_ time: UInt8) {
        try? writeRegister(.atime, time)
    }



    func setGain(_ gain: Gain) {
        try? writeRegister(.CFG1, gain.rawValue)
    }

    enum Gain: UInt8 {
        case xhalf = 0
        case x1 = 1
        case x2 = 2
        case x4 = 3
        case x8 = 4
        case x16 = 5
        case x32 = 6
        case x64 = 7
        case x128 = 8
        case x256 = 9
        case x512 = 10
    }


}

extension AS7341 {
    enum Register: UInt8 {
        case config = 0x70
        case enable = 0x80
        case atime = 0x81
        case id = 0x92
        case CFG1 = 0xAA
        case astepLSB = 0xCA
    }

    private func writeRegister(_ register: Register, _ value: UInt8) throws {
        let result = i2c.write([register.rawValue, value], to: address)
        if case .failure(let err) = result {
            throw err
        }
    }

    private func writeRegister(_ register: UInt8, _ value: UInt8) throws {
        let result = i2c.write([register, value], to: address)
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

    func enableLEDControl() {
        var config: UInt8 = 0
        try? readRegister(.config, into: &config)
        try? writeRegister(.config, config | 0b1000)
    }

    func powerOn() {
        var enable: UInt8 = 0
        try? readRegister(.enable, into: &enable)
        try? writeRegister(.enable, enable | 0b1)
    }

    func getID() -> UInt8 {
        var id: UInt8 = 0
        try? readRegister(.id, into: &id)
        return id & 0xFC
    }



}
