
import SwiftIO


class AHTx0 {
    private let i2c: I2C
    private let address: UInt8

    init(i2c: I2C, address: UInt8 = 0x38) {
        self.i2c = i2c
        self.address = address

        sleep(ms: 20)
        reset()
        calibrate()
    }


    func reset() {
        i2c.write(0xBA, to: address)
        sleep(ms: 20)
    }

    func calibrate() {
        i2c.write([0xE1, 0x08, 0x00], to: address)
        var byte: UInt8 = 0

        repeat {
            i2c.read(into: &byte, from: address)
            sleep(ms: 10)
        } while byte & 0x80 != 0

        if byte & 0x08 == 0 {
            fatalError(#function + ": calibration for AHTx0 failed")
        }
    }


    enum Command: UInt8 {
        case softReset = 0xBA
    }
}

