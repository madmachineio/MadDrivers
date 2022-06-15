
import SwiftIO

/// This is the library for MLX90393 magnetic field sensor.
///
/// The sensor supports I2C and SPI communication. It can measure 5-50mT in 3 axes
/// and detect magnetic orientation. You can set the gain, resolution,
/// oversampling ratio, filter to adjust the sensor's sensitivity and behavior.
final public class MLX90393 {
    private let i2c: I2C?
    private let spi: SPI?
    private let csPin: DigitalOut?
    private let address: UInt8

    private var readBuffer = [UInt8](repeating: 0, count: 8)

    private var filter: Filter
    private var oversampling: Oversampling
    var xResolution: Resolution
    var yResolution: Resolution
    var zResolution: Resolution
    var gain: Gain

    private let allAxis: UInt8 = 0x0E
    private let hallCONF: UInt8 = 0x0C

    private let tCONV: [[Float]] = [
        [1.27, 1.84, 3.00, 5.30],
        [1.46, 2.23, 3.76, 6.84],
        [1.84, 3.00, 5.30, 9.91],
        [2.61, 4.53, 8.37, 16.05],
        [4.15, 7.60, 14.52, 28.34],
        [7.22, 13.75, 26.80, 52.92],
        [13.36, 26.04, 51.38, 102.07],
        [25.65, 50.61, 100.53, 200.37]]

    private let sensitivity: [[[Float]]] = [
        [[0.751, 1.210], [1.502, 2.420], [3.004, 4.840], [6.009, 9.680]],
        [[0.601, 0.968], [1.202, 1.936], [2.403, 3.872], [4.840, 7.744]],
        [[0.451, 0.726], [0.901, 1.452], [1.803, 2.904], [3.605, 5.808]],
        [[0.376, 0.605], [0.751, 1.210], [1.502, 2.420], [3.004, 4.840]],
        [[0.300, 0.484], [0.601, 0.968], [1.202, 1.936], [2.403, 3.872]],
        [[0.250, 0.403], [0.501, 0.807], [1.001, 1.613], [2.003, 3.227]],
        [[0.200, 0.323], [0.401, 0.645], [0.801, 1.291], [1.602, 2.581]],
        [[0.150, 0.242], [0.300, 0.484], [0.601, 0.968], [1.202, 1.936]]]

    private var time: Float {
        return tCONV[Int(filter.rawValue)][Int(oversampling.rawValue)]
    }

    /// Initialize the sensor using I2C communication.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects. It only
    ///   supports 100kHz (standard) and 400kHz (fast) I2C speed.
    ///   - address: **OPTIONAL** The device address of the sensor, 0x0C by default.
    public init(_ i2c: I2C, address: UInt8 = 0x0C) {
        let speed = i2c.getSpeed()
        guard speed == .standard || speed == .fast else {
            fatalError(#function + ": MLX90393 only supports 100kHz (standard) and 400kHz (fast) I2C speed.")
        }

        self.i2c = i2c
        self.address = address
        self.spi = nil
        self.csPin = nil

        filter = .filter7
        oversampling = .osr3
        xResolution = .resolution16
        yResolution = .resolution16
        zResolution = .resolution16
        gain = .x1

        reset()

        setResolution(x: xResolution, y: yResolution, z: zResolution)
        setFilter(filter)
        setOversampling(oversampling)
        setGain(gain)
    }

    /// Initialize the sensor using SPI communication.
    /// - Parameters:
    ///   - spi: **REQUIRED** The SPI interface that the sensor connects.
    ///   The maximum SPI clock speed is **10MHz**. Both of the **CPOL and CPHA**
    ///   should be **true**.
    ///   - csPin: **OPTIONAL** The cs pin for the spi. If you set the cs when
    ///   initializing the spi interface, `csPin` should be nil. If not, you
    ///   need to set a digital output pin as the cs pin. And the mode of the pin
    ///   should be **pushPull**.
    public init(_ spi: SPI, csPin: DigitalOut? = nil) {
        self.spi = spi
        self.csPin = csPin

        self.i2c = nil
        self.address = 0

        csPin?.high()

        filter = .filter7
        oversampling = .osr3
        xResolution = .resolution16
        yResolution = .resolution16
        zResolution = .resolution16
        gain = .x1

        guard (spi.cs == false && csPin != nil && csPin!.getMode() == .pushPull)
                || (spi.cs == true && csPin == nil) else {
                    fatalError(#function + ": csPin isn't correctly configured")
        }

        guard spi.getMode() == (true, true, .MSB) else {
            fatalError(#function + ": SPI mode doesn't match for MLX90393. CPOL and CPHA should be true and bitOrder should be .MSB")
        }

        guard spi.getSpeed() <= 10_000_000 else {
            fatalError(#function + ": MLX90393 cannot support SPI speed faster than 10MHz")
        }

        reset()

        setResolution(x: xResolution, y: yResolution, z: zResolution)
        setFilter(filter)
        setOversampling(oversampling)
        setGain(gain)
    }


    /// Read the magnetic flux density on x, y, z-axis in microteslas.
    /// - Returns: The density on x, y, z-axis in microteslas.
    public func readXYZ() -> (x: Float, y: Float, z: Float) {
        try? writeCommand(Command.sm.rawValue | allAxis)
        sleep(ms: Int(time * 1.1))

        try? readCommand(Command.rm.rawValue | allAxis, into: &readBuffer, count: 7)

        var x = calculateRaw(xResolution, msb: readBuffer[1], lsb: readBuffer[2])
        var y = calculateRaw(yResolution, msb: readBuffer[3], lsb: readBuffer[4])
        var z = calculateRaw(zResolution, msb: readBuffer[5], lsb: readBuffer[6])

        x *= sensitivity[Int(gain.rawValue)][Int(xResolution.rawValue)][0]
        y *= sensitivity[Int(gain.rawValue)][Int(yResolution.rawValue)][0]
        z *= sensitivity[Int(gain.rawValue)][Int(zResolution.rawValue)][1]

        return (x, y, z)
    }

    /// Set the resolution for x, y, z-axis to change the sensor's sensibility.
    /// - Parameters:
    ///   - x: A resolution setting for x-axis in ``Resolution``.
    ///   - y: A resolution setting for y-axis in ``Resolution``.
    ///   - z: A resolution setting for z-axis in ``Resolution``.
    public func setResolution(x: Resolution, y: Resolution, z: Resolution) {
        try? readRegister(.config3, into: &readBuffer, count: 3)

        var msb = readBuffer[1]
        var lsb = readBuffer[2]

        msb = (msb & 0b1111_1000) | (z.rawValue << 1) | (y.rawValue >> 1)
        lsb = (lsb & 0b0001_1111) | (y.rawValue << 7) | (x.rawValue << 5)

        try? writeRegister(.config3, data: [msb, lsb])
        xResolution = x
        yResolution = y
        zResolution = z
    }

    /// Get the resolution settings.
    /// - Returns: The resolutions for 3 axes in ``Resolution``.
    public func getResolution() -> (x: Resolution, y: Resolution, z: Resolution) {
        return (xResolution, yResolution, zResolution)
    }

    /// Set the filter which directly impact the time for magnetic measurements.
    /// - Parameter filter: A filter setting in ``Filter``.
    public func setFilter(_ filter: Filter) {
        try? readRegister(.config3, into: &readBuffer, count: 3)
        let msb = readBuffer[1]
        var lsb = readBuffer[2]
        lsb = (lsb & 0b1110_0011) | (filter.rawValue << 2)
        try? writeRegister(.config3, data: [msb, lsb])
        self.filter = filter
    }

    /// Get the filter setting for the ADC.
    /// - Returns: A filter setting in ``Filter``.
    public func getFilter() -> Filter {
        return filter
    }

    /// Set the ADC oversampling ratio which directly impact the time for
    /// magnetic measurements.
    /// - Parameter oversampling: An oversampling ratio in ``Oversampling``.
    public func setOversampling(_ oversampling: Oversampling) {
        try? readRegister(.config3, into: &readBuffer, count: 3)
        let msb = readBuffer[1]
        var lsb = readBuffer[2]
        lsb = (lsb & 0b1111_1100) | (oversampling.rawValue)
        try? writeRegister(.config3, data: [msb, lsb])
        self.oversampling = oversampling
    }

    /// Get current oversampling ratio.
    /// - Returns: An oversampling ratio in ``Oversampling``.
    public func getOversampling() -> Oversampling {
        return oversampling
    }

    /// Set the gain to change the sensor's sensibility.
    /// - Parameter gain: A gain setting in ``Gain``.
    public func setGain(_ gain: Gain) {
        try? writeRegister(.config1, data: [0, (gain.rawValue << 4) | hallCONF])
        self.gain = gain
    }

    /// Get the gain setting.
    /// - Returns: A gain setting in ``Gain``.
    public func getGain() -> Gain {
        return gain
    }

    /// The filter settings for ADC to change the time for magnetic measurements.
    public enum Filter: UInt8 {
        case filter0 = 0
        case filter1 = 1
        case filter2 = 2
        case filter3 = 3
        case filter4 = 4
        case filter5 = 5
        case filter6 = 6
        case filter7 = 7
    }

    /// The gain settings to change the sensor's sensibility.
    public enum Gain: UInt8 {
        case x5 = 0
        case x4 = 1
        case x3 = 2
        case x2_5 = 3
        case x2 = 4
        case x1_67 = 5
        case x1_33 = 6
        case x1 = 7
    }

    /// The oversampling ratios to change the time of magnetic measurement.
    public enum Oversampling: UInt8 {
        case osr0 = 0
        case osr1 = 1
        case osr2 = 2
        case osr3 = 3
    }

    /// The resolution settings for each axis for the sensor's sensibility.
    public enum Resolution: UInt8 {
        case resolution16 = 0
        case resolution17 = 1
        case resolution18 = 2
        case resolution19 = 3
    }
}


extension MLX90393 {
    enum Command: UInt8 {
        case rr = 0x50
        case wr = 0x60
        case sm = 0x30
        case rm = 0x40
        case rt = 0xF0
    }

    enum Register: UInt8 {
        case config1 = 0x00
        case config3 = 0x02
    }

    func readRegister(
        _ register: Register, into buffer: inout [UInt8], count: Int
    ) throws {
        for i in 0..<buffer.count {
            buffer[i] = 0
        }

        let data = [Command.rr.rawValue, register.rawValue << 2]

        var result: Result<(), Errno>

        if i2c != nil {
            result = i2c!.write(data, to: address)
            if case .failure(let err) = result {
                throw err
            }

            // The first byte is status byte, the last two bytes are 16-bit value.
            result = i2c!.read(into: &buffer, count: 3, from: address)
        } else {
            csPin?.low()
            result = spi!.transceive(data, into: &buffer, readCount: 3+2)
            csPin?.high()
        }

        if case .failure(let err) = result {
            throw err
        }
    }

    func writeRegister(_ register: Register, data: [UInt8]) throws {
        var data = data
        data.insert(Command.wr.rawValue, at: 0)
        data.append(register.rawValue << 2)

        var status: [UInt8] = [0]

        var result: Result<(), Errno>

        if i2c != nil {
            result = i2c!.writeRead(data, into: &status, address: address)
        } else {
            var tempBuffer: [UInt8] = [0, 0, 0]
            csPin?.low()
            result = spi!.transceive(data, into: &tempBuffer)
            csPin?.high()
            status[0] = tempBuffer[2]
        }

        if case .failure(let err) = result {
            throw err
        }
    }

    func writeCommand(_ command: UInt8) throws {
        var status: UInt8 = 0
        var result: Result<(), Errno>
        if i2c != nil {
            result = i2c!.writeRead(command, into: &status, address: address)
        } else {
            var tempBuffer: [UInt8] = [0, 0]
            csPin?.low()
            result = spi!.transceive(command, into: &tempBuffer)
            csPin?.high()
            status = tempBuffer[1]
        }

        if case .failure(let err) = result {
            throw err
        }
    }

    func readCommand(
        _ command: UInt8, into buffer: inout [UInt8], count: Int
    ) throws {
        var result: Result<(), Errno>
        if i2c != nil {
            result = i2c!.writeRead(command, into: &buffer,
                                    readCount: count, address: address)
        } else {
            csPin?.low()
            result = spi!.transceive(command, into: &buffer, readCount: count + 1)
            csPin?.high()

            for i in 0..<count {
                buffer[i] = buffer[i + 1]
            }
        }

        if case .failure(let err) = result {
            throw err
        }
    }

    func reset() {
        sleep(ms: 2000)
        try? writeCommand(Command.rt.rawValue)
    }

    func calculateRaw(_ resolution: Resolution, msb: UInt8, lsb: UInt8) -> Float {
        if resolution == .resolution19 {
            return Float(UInt16(msb) << 8 | UInt16(lsb)) - 0x4000
        } else if resolution == .resolution18 {
            return Float(UInt16(msb) << 8 | UInt16(lsb)) - 0x8000
        } else {
            return Float(Int16(msb) << 8 | Int16(lsb))
        }
    }
}
