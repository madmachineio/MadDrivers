
import SwiftIO

final public class AS7341 {
    private let i2c: I2C
    private let address: UInt8

    private var readBuffer = [UInt8](repeating: 0, count: 13)

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

    func readF1F8() -> Channels {
        setF1F4()
        if isDataReady() {
            try? readRegister(.astatus, into: &readBuffer, count: 13)
        }

        let f1 = calUInt16(readBuffer[1], readBuffer[2])
        let f2 = calUInt16(readBuffer[3], readBuffer[4])
        let f3 = calUInt16(readBuffer[5], readBuffer[6])
        let f4 = calUInt16(readBuffer[7], readBuffer[8])

        setF5F8()
        if isDataReady() {
            try? readRegister(.astatus, into: &readBuffer, count: 13)
        }

        let f5 = calUInt16(readBuffer[1], readBuffer[2])
        let f6 = calUInt16(readBuffer[3], readBuffer[4])
        let f7 = calUInt16(readBuffer[5], readBuffer[6])
        let f8 = calUInt16(readBuffer[7], readBuffer[8])

        return Channels(f1: f1, f2: f2, f3: f3, f4: f4,
                        f5: f5, f6: f6, f7: f7, f8: f8)
    }


    func calUInt16(_ lsb: UInt8, _ msb: UInt8) -> UInt16 {
        return UInt16(lsb) | UInt16(msb) << 8
    }

    struct Channels {
        let f1: UInt16
        let f2: UInt16
        let f3: UInt16
        let f4: UInt16
        let f5: UInt16
        let f6: UInt16
        let f7: UInt16
        let f8: UInt16

        init(f1: UInt16, f2: UInt16, f3: UInt16, f4: UInt16,
             f5: UInt16, f6: UInt16, f7: UInt16, f8: UInt16) {
            self.f1 = f1
            self.f2 = f2
            self.f3 = f3
            self.f4 = f4
            self.f5 = f5
            self.f6 = f6
            self.f7 = f7
            self.f8 = f8
        }
    }



    func setF1F4() {
        /// Disable the Spectral Measurement before sensor configuration.
        disableColorMeasure()

        /// Select SMUX command to write SMUX configurations.
        setSmuxCommand(2)

        /// Map F1 to F4, CLEAR, NIR to 6 internal ADCs.
        setSmuxF1F4()

        /// Starts SMUX command. It will be disabled automatically after SMUX
        /// operation is finished.
        enableSmux()

        enableColorMeasure()
    }

    func setF5F8() {
        /// Disable the Spectral Measurement before sensor configuration.
        disableColorMeasure()

        /// Select SMUX command to write SMUX configurations.
        setSmuxCommand(2)

        /// Map F1 to F4, CLEAR, NIR to 6 internal ADCs.
        setSmuxF5F8()

        /// Starts SMUX command. It will be disabled automatically after SMUX
        /// operation is finished.
        enableSmux()

        enableColorMeasure()
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
        case astatus = 0x94
        case CH0_DATA_L = 0x95
        case CH1_DATA_L = 0x97
        case CH2_DATA_L = 0x99
        case CH3_DATA_L = 0x9B
        case CH4_DATA_L = 0x9D
        case CH5_DATA_L = 0x9F
        case status2 = 0xA3
        case CFG1 = 0xAA
        case CFG6 = 0xAF
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

    private func readRegister(_ register: Register, into buffer: inout [UInt8], count: Int) throws {
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

    enum Enable: UInt8 {
        case powerOn = 0b00001
        case colorMeasure = 0b0010
        case colorMeasureMask = 0b1111_1101
        case smux = 0b0001_0000
    }

    func getID() -> UInt8 {
        var id: UInt8 = 0
        try? readRegister(.id, into: &id)
        return id & 0xFC
    }

    func enableLEDControl() {
        var config: UInt8 = 0
        try? readRegister(.config, into: &config)
        try? writeRegister(.config, config | 0b1000)
    }

    // ===--- Set Enable register ----------------------------------------=== //

    func powerOn() {
        var enable: UInt8 = 0
        try? readRegister(.enable, into: &enable)
        try? writeRegister(.enable, enable | Enable.powerOn.rawValue)
    }

    func enableSmux() {
        var enable: UInt8 = 0
        try? readRegister(.enable, into: &enable)
        try? writeRegister(.enable, enable | Enable.smux.rawValue)
    }

    func enableColorMeasure() {
        var enable: UInt8 = 0
        try? readRegister(.enable, into: &enable)
        try? writeRegister(.enable, enable | Enable.colorMeasure.rawValue)
    }

    func disableColorMeasure() {
        var enable: UInt8 = 0
        try? readRegister(.enable, into: &enable)
        try? writeRegister(.enable, enable & Enable.colorMeasureMask.rawValue)
    }


    /// Select SMUX command.
    func setSmuxCommand(_ command: UInt8) {
        try? writeRegister(.CFG6, command)
    }

    // ===--- Set Sensor multiplexer -------------------------------------=== //

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

    func setSmux(_ smuxIn: SmuxIn, _ smuxOut1: SmuxOut, _ smuxOut2: SmuxOut) {
        try? writeRegister(smuxIn.rawValue, UInt8(smuxOut1.rawValue) | UInt8(smuxOut2.rawValue << 4))
    }

    /// Set sensor multiplexer (SMUX) for sensors F1 to F4, clear and NIR to map
    /// them into 6 internal ADCs.
    func setSmuxF1F4() {
        /// Set F3 left to ADC2
        setSmux(.NC_F3L, .disable, .adc2)
        /// F1 left to ADC0
        setSmux(.F1L_NC, .adc0, .disable)
        /// Reserved or disabled
        setSmux(.NC_NC0, .disable, .disable)
        /// Disable F8 left
        setSmux(.NC_F8L, .disable, .disable)
        /// Disable F6 left
        setSmux(.F6L_NC, .disable, .disable)
        /// Set F4 left to ADC3 and F2 left to ADC1
        setSmux(.F2L_F4L, .adc1, .adc3)
        /// Disable F5 left
        setSmux(.NC_F5L, .disable, .disable)
        /// Disable F7 left
        setSmux(.F7L_NC, .disable, .disable)
        /// Set CLEAR to ADC4
        setSmux(.NC_CL, .disable, .adc4)
        /// Disable F5 right
        setSmux(.NC_F5R, .disable, .disable)
        /// Disable F7 right
        setSmux(.F7R_NC, .disable, .disable)
        /// Reserved or disabled
        setSmux(.NC_NC1, .disable, .disable)
        /// Set F2 right to ADC1
        setSmux(.NC_F2R, .disable, .adc1)
        /// Set F4 right to ADC3
        setSmux(.F4R_NC, .adc3, .disable)
        /// Disable F6 and F8 right
        setSmux(.F8R_F6R, .disable, .disable)
        /// Set F3 right to ADC2
        setSmux(.NC_F3R, .disable, .adc2)
        /// Set F1 right to ADC0
        setSmux(.F1R_EXT_GPIO, .adc0, .disable)
        /// Set CLEAR to ADC4
        setSmux(.EXT_INT_CR, .disable, .adc4)
        /// Reserved or disabled
        setSmux(.NC_DARK, .disable, .disable)
        /// Set NIR to ADC5
        setSmux(.NIR_F, .adc5, .disable)
    }

    /// Set sensor multiplexer (SMUX) for sensors F5 to F8, clear and NIR to map
    /// them into 6 internal ADCs.
    func setSmuxF5F8() {
        /// Disable F3 left
        setSmux(.NC_F3L, .disable, .disable)
        /// Disable F1 left
        setSmux(.F1L_NC, .disable, .disable)
        /// Reserved or disabled
        setSmux(.NC_NC0, .disable, .disable)
        /// Set F8 left to ADC3
        setSmux(.NC_F8L, .disable, .adc3)
        /// Set F6 left to ADC1
        setSmux(.F6L_NC, .adc1, .disable)
        /// Disable F4 and F2 left
        setSmux(.F2L_F4L, .disable, .disable)
        /// Set F5 left to ADC0
        setSmux(.NC_F5L, .disable, .adc0)
        /// Set F7 left to ADC2
        setSmux(.F7L_NC, .adc2, .disable)
        /// Set CLEAR to ADC4
        setSmux(.NC_CL, .disable, .adc4)
        /// Set F5 right to ADC0
        setSmux(.NC_F5R, .disable, .adc0)
        /// Set F7 right to ADC2
        setSmux(.F7R_NC, .adc2, .disable)
        /// Reserved or disabled
        setSmux(.NC_NC1, .disable, .disable)
        /// Disable F2 right
        setSmux(.NC_F2R, .disable, .disable)
        /// Disable F4 right
        setSmux(.F4R_NC, .disable, .disable)
        /// Set F8 right to ADC2 and F6 right to ADC1
        setSmux(.F8R_F6R, .adc3, .adc1)
        /// Disable F3 right
        setSmux(.NC_F3R, .disable, .disable)
        /// Disable F1 right
        setSmux(.F1R_EXT_GPIO, .disable, .disable)
        /// Set CLEAR to ADC4
        setSmux(.EXT_INT_CR, .disable, .adc4)
        /// Reserved or disabled
        setSmux(.NC_DARK, .disable, .disable)
        /// Set NIR to ADC5
        setSmux(.NIR_F, .adc5, .disable)
    }


    func isDataReady(_ timeout: UInt64 = 1000) -> Bool {
        var status: UInt8 = 0

        let start = getSystemUptimeInMilliseconds()

        try? readRegister(.status2, into: &status)

        while status & 0b0100_0000 == 0 {
            if getSystemUptimeInMilliseconds() - start > timeout {
                print(#function + ": Timeout waiting for data from sensor")
                return false
            }
            sleep(ms: 1)
            try? readRegister(.status2, into: &status)
        }

        return true
    }


}




