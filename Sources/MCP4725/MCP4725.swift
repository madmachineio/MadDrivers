import SwiftIO

final public class MadMCP4725 {
    enum WriteType: UInt8 {
        case writeDAC = 0x40
        case writeBothDACEEROM = 0x60
    }

    let i2c: I2C
    let referenceVoltage: Double

    let address: UInt8
    let maxRawValue = Int(4095)

    public init(_ i2c: I2C, address: UInt8 = 0x60, referenceVoltage: Double = 3.3, outputVoltage: Double? = nil) {
        self.i2c = i2c
        self.address = address
        self.referenceVoltage = referenceVoltage
        if let voltage = outputVoltage {
            setOutputVoltage(voltage)
        } else {
            setOutputVoltage(0.0)
        }
    }

    public func getOutputVoltage() -> Double {
        return Double(getOutputValue()) / Double(maxRawValue) * referenceVoltage
    }

    public func getOutputRawValue() -> Int {
        return Int(getOutputValue())
    }

    public func setRawValue(_ newValue: Int, writeToEEROM: Bool = false) {
        guard newValue >= 0 && newValue <= maxRawValue else {
            print("value \(newValue) is not acceptable!")
            return
        }

        let value = UInt16(newValue)
        var data = [UInt8](repeating: 0x00, count: 3)

        if writeToEEROM {
            data[0] = WriteType.writeBothDACEEROM.rawValue
        } else {
            data[0] = WriteType.writeDAC.rawValue
        }

        data[1] = UInt8((value & 0x0FF0) >> 4)
        data[2] = UInt8((value & 0x000F) << 4)

        i2c.write(data, to: address)
    }

    public func setOutputVoltage(_ voltage: Double, writeToEEROM: Bool = false) {
        guard voltage >= 0.0 && voltage <= referenceVoltage else {
            print("voltage \(voltage) is not acceptable!")
            return
        }

        let value = UInt16(voltage / referenceVoltage * Double(maxRawValue))
        var data = [UInt8](repeating: 0x00, count: 3)

        if writeToEEROM {
            data[0] = WriteType.writeBothDACEEROM.rawValue
        } else {
            data[0] = WriteType.writeDAC.rawValue
        }

        data[1] = UInt8((value & 0x0FF0) >> 4)
        data[2] = UInt8((value & 0x000F) << 4)

        i2c.write(data, to: address)
    }

    public func fastWrite(_ voltages: [Double]) {
        var data = [UInt8](repeating: 0x00, count: voltages.count * 2)

        for index in 0..<voltages.count {
            let value = UInt16(voltages[index] / referenceVoltage * Double(maxRawValue))
            data[index * 2] = UInt8(value >> 8)
            data[index * 2 + 1] = UInt8(value & 0xFF)
        }

        i2c.write(data, to: address)
    }
}


extension MadMCP4725 {
    func getEEROMValue() -> UInt16 {
        let data = i2c.read(count: 5, from: address)
        let high = UInt16(data[3] & 0x0F) << 8
        let low = UInt16(data[4])

        return high | low
    }

    func getOutputValue() -> UInt16 {
        let data = i2c.read(count: 5, from: address)
        let high = UInt16(data[1] & 0xF0) << 4
        let low = (UInt16(data[1] & 0x0F) << 4) | (UInt16(data[2] & 0xF0) >> 4)

        return high | low
    }
    
}