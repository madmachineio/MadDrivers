//=== BME680.swift --------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 12/15/2021
// Updated: 12/15/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//
import SwiftIO
import RealModule

/// This is the library for BME680 gas, humidity, pressure and temperature sensor.
///
/// The sensor measures multiple VOC gases, like ethanol, carbon monoxide,
/// etc, but cannot tell which one is changing. It will heat the hot plate inside
/// it to a target temperature for some time before its measurement.
/// Then the oxygen would be absorbed on its sensitive layer and finally
/// change its resistance. More VOC gases in the air will
/// cause a lower resistance.
///
/// Because of the sensor will produce heat during measurement, the temperature
/// returned may be a little higher than the actual value.
final public class BME680 {
    private let i2c: I2C?
    private let address: UInt8?
    private let spi: SPI?

    private var tSampling: Oversampling
    private var hSampling: Oversampling
    private var pSampling: Oversampling
    private var filter: Filter
    private var mode: Mode

    var tCoeff: [Double] = []
    var pCoeff: [Double] = []
    var hCoeff: [Double] = []
    var gCoeff: [Double] = []
    var heaterRange: Double = 0
    var heatValue: Double = 0
    var rangeSwitchingError: Double = 0

    private let lookupTable1 = [
        1, 1, 1, 1, 1, 0.99, 1, 0.992,
        1, 1, 0.998, 0.995, 1, 0.99, 1, 1]

    private let lookupTable2 = [
        8000000, 4000000, 2000000, 1000000,
        499500.4995, 248262.1648, 125000, 63004.03226,
        31281.28128, 15625, 7812.5, 3906.25, 1953.125,
        976.5625, 488.28125, 244.140625]

    /// Initialize the sensor using I2C communication.
    ///
    /// - Attention: The sensor's address depends on the pin SDO. If you connect
    /// the pin to GND, the address is 0x76. If you connect the pin to power,
    /// the address if 0x77. If the pin is unconnected, the address is undefined.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the sensor connects.
    ///   - address: **OPTIONAL** The device address of the sensor.
    public init(_ i2c: I2C, address: UInt8 = 0x77) {
        self.i2c = i2c
        self.address = address
        self.spi = nil

        tSampling = .x8
        hSampling = .x2
        pSampling = .x4
        filter = .size3
        mode = .sleep

        reset()

        guard let chipID = readRegister(.chipID), chipID == 0x61 else {
            fatalError(#function + ": cannot find BME680 at address \(address)")
        }

        readCalibration()

        // Set temperature, pressure, humidity oversampling.
        writeCtrlMeas()
        setHumiditySampling(hSampling)
        // Set filter for the temperature and pressure measurement.
        setFilter(filter)
        // Set heater to 320 degree celsius for 150ms.
        setHeater(320, 150)
        // Enable gas conversion.
        writeRegister(.ctrlGas1, 0x10)
    }

    /// Read current temperature in Celsius.
    /// - Returns: The temperature in Celsius.
    public func readTemperature() -> Double {
        let data = readRawValues()
        let temp = data[5] / 5120
        return temp
    }

    /// Measure current barometric pressure in hPa.
    /// - Returns: The pressure in hPa.
    public func readPressure() -> Double {
        let data = readRawValues()
        let tFine = data[5]

        var value1 = tFine / 2 - 64000
        var value2 = value1 * value1 * (pCoeff[5] / 131072)
        value2 = value2 + value1 * pCoeff[4] * 2
        value2 = value2 / 4 + pCoeff[3] * 65536
        value1 = ((pCoeff[2] * value1 * value1) / 16384 +
                  (pCoeff[1] * value1)) / 524288
        value1 = (1 + value1 / 32768) * pCoeff[0]
        var pressure = 1048576 - data[0]

        guard value1 != 0 else { return 0 }

        pressure = (pressure - value2 / 4096) * 6250.0 / value1
        value1 = pCoeff[8] * pressure * pressure / 2147483648
        value2 = pressure * (pCoeff[7] / 32768)
        let value3 = (pressure / 256) * (pressure / 256) *
                    (pressure / 256) * (pCoeff[9] / 131072)
        pressure = pressure + (value1 + value2 + value3 + pCoeff[6] * 128) / 16

        return pressure / 100
    }

    /// Calculate the altitude above sea level in meter.
    ///
    /// The altitude is calculated based on the sea level pressure.
    /// You can find the current sea level pressure here:
    /// https://weather.us/observations/usa/pressure-qff/20211203-0400z.html
    /// - Parameter seaLevelPressure: The sea level pressure in hPa.
    /// - Returns: The altitude in meter.
    public func readAltitude(_ seaLevelPressure: Double) -> Double {
        let pressure = readPressure()
        let altitude = 44330 * (1.0 - Double.pow(pressure / seaLevelPressure, 0.1903))
        return altitude
    }

    /// Read current relative humidity.
    /// - Returns: The humidity in percentage.
    public func readHumidity() -> Double {
        let data = readRawValues()
        let temp = data[5] / 5120

        let value1 = data[2] - (hCoeff[0] * 16 + hCoeff[2] / 2 * temp)

        let value2 = value1 * ((hCoeff[1] / 262144) *
                               (1 + hCoeff[3] / 16384 * temp +
                                hCoeff[4] / 1048576 * temp * temp))

        let value3 = hCoeff[5] / 16384
        let value4 = hCoeff[6] / 2097152
        var hum = value2 + (value3 + value4 * temp) * value2 * value2
        if hum > 100 {
            hum = 100
        } else if hum < 0 {
            hum = 0
        }
        return hum
    }

    /// Measure the VOC in the air and return the resistance of the gas sensor.
    /// If the resistance is higher, the air is cleaner.
    /// - Returns: The gas resistance in ohms.
    public func readGasResistance() -> Double {
        let data = readRawValues()
        let rawGas = data[3]
        let gasRange = Int(data[4])

        let value1 = (1340 + 5 * rangeSwitchingError) * lookupTable1[gasRange]
        let gas = value1 * lookupTable2[gasRange] / (rawGas - 512 + value1)

        return gas
    }

    /// Set the heater temperature and duration for the gas sensor.
    /// It only works during gas measurement.
    /// - Parameters:
    ///   - temp: The target heater temperature, typically between 200 and 400
    ///     degree celsius.
    ///   - duration: The heating duration, between 1ms and 4032ms.
    public func setHeater(_ temp: Int, _ duration: Int) {
        mode = .sleep
        writeCtrlMeas()

        let gasWait = calGasWait(duration)
        let gasHeat = calGasHeat(temp)

        writeRegister(.gasWait0, gasWait)
        writeRegister(.resHeat0, gasHeat)
    }

    /// Set oversampling rate for the humidity measurement.
    /// - Parameter hSampling: An Oversampling setting.
    public func setHumiditySampling(_ hSampling: Oversampling) {
        self.hSampling = hSampling
        writeRegister(.ctrlHum, hSampling.rawValue)
    }

    /// Set oversampling rate for the temperature measurement.
    /// - Parameter tSampling: An Oversampling setting.
    public func setTempOversampling(_ tSampling: Oversampling) {
        self.tSampling = tSampling
        writeCtrlMeas()
    }

    /// Get oversampling rate for the temperature measurement.
    /// - Returns: An Oversampling setting.
    public func getTempOversampling() -> Oversampling {
        return self.tSampling
    }

    /// Get oversampling rate for the pressure measurement.
    /// - Returns: A Oversampling setting.
    public func getPressureOversampling() -> Oversampling {
        return self.pSampling
    }

    /// Set oversampling rate for the pressure measurement.
    /// - Parameter pSampling: A Oversampling setting.
    public func setPressureOversampling(_ pSampling: Oversampling) {
        self.pSampling = pSampling
        writeCtrlMeas()
    }



    /// Set IIR filter level for the pressure and temperature measurement.
    /// The humidity and gas measurement doesn't need the filter.
    /// - Parameter filter: A filter setting in `Filter` enumeration.
    public func setFilter(_ filter: Filter) {
        self.filter = filter
        writeRegister(.config, filter.rawValue << 2)
    }

    /// Get IIR filter setting for the measurement.
    /// - Returns: A filter level in `Filter` enumeration.
    public func getFilter() -> Filter {
        return filter
    }

    /// Oversampling rate for temperature, pressure and humidity measurement.
    public enum Oversampling: UInt8 {
        case disable = 0
        case x1 = 0b001
        case x2 = 0b010
        case x4 = 0b011
        case x8 = 0b100
        case x16 = 0b101
    }

    /// IIR filter coefficient for the sensor to minimize the disturbances.
    public enum Filter: UInt8 {
        case size0 = 0b000
        case size1 = 0b001
        case size3 = 0b010
        case size7 = 0b011
        case size15 = 0b100
        case size31 = 0b101
        case size63 = 0b110
        case size127 = 0b111
    }
}

extension BME680 {
    enum Register: UInt8 {
        case chipID = 0xD0
        case reset = 0xE0
        case resHeat0 = 0x5A
        case gasWait0 = 0x64
        case ctrlGas1 = 0x71
        case ctrlHum = 0x72
        case ctrlMeas = 0x74
        case config = 0x75
        case coeff1 = 0x8A
        case coeff2 = 0xE1
        case coeff3 = 0x00
        case measStatus0 = 0x1D
    }

    /// Power mode. It decides how the sensor performs the measurement.
    private enum Mode: UInt8 {
        /// The default mode after power on. No measurements will be performed.
        case sleep = 0b00
        /// The device performs a single measurement and then enter sleep mode.
        case force = 0b01
    }

    /// Set temperature and pressure oversampling settings and power mode.
    private func writeCtrlMeas() {
        let ctrlMeas = tSampling.rawValue << 5 |
        pSampling.rawValue << 2 | mode.rawValue

        writeRegister(.ctrlMeas, ctrlMeas)
    }

    private func writeRegister(_ register: Register, _ value: UInt8) {
        if let i2c = i2c {
            i2c.write([register.rawValue, value], to: address!)
        } else if let spi = spi {
            spi.write([register.rawValue, value])
        }
    }

    private func readRegister(_ register: Register) -> UInt8? {
        var data: UInt8? = nil

        if let i2c = i2c {
            i2c.write(register.rawValue, to: address!)
            data = i2c.readByte(from: address!)
        } else if let spi = spi {
            spi.write(register.rawValue)
            data = spi.readByte()
        }

        return data
    }

    private func readRegister(_ register: Register, count: Int) -> [UInt8] {
        var data: [UInt8] = Array(repeating: 0, count: count)

        if let i2c = i2c {
            i2c.write(register.rawValue, to: address!)
            data = i2c.read(count: count, from: address!)
        } else if let spi = spi {
            spi.write(register.rawValue)
            data = spi.read(count: count)
        }

        return data
    }

    /// Calculate the heating duration into an UInt8 value for the register.
    private func calGasWait(_ duration: Int) -> UInt8 {
        var factor = 0
        var durationValue = 0
        var duration = duration

        guard duration <= 4032 else { return 0xFF }

        while duration > 0x3F {
            duration /= 4
            factor += 1
        }

        durationValue = duration + factor * 64
        return UInt8(durationValue)
    }

    /// Calculate the temperature into an UInt8 value for the register.
    private func calGasHeat(_ temp: Int) -> UInt8 {
        let ambTemp = 25.0

        let value1 = gCoeff[0] / 16.0 + 49.0
        let value2 = gCoeff[1] / 32768.0 * 0.0005 + 0.00235
        let value3 = gCoeff[2] / 1024.0
        let value4 = value1 * (1.0 + value2 * Double(temp))
        let value5 = value4 + (value3 * ambTemp)
        let heatValue = 3.4 * ((value5 * (4 / (4 + heaterRange)) *
                                (1 / (1 + heatValue * 0.002))) - 25)

        return UInt8(heatValue)
    }

    private func reset() {
        writeRegister(.reset, 0xB6)
        sleep(ms: 5)
    }

    func readCalibration() {
        let coeff1 = readRegister(.coeff1, count: 23)
        let coeff2 = readRegister(.coeff2, count: 14)
        let coeff3 = readRegister(.coeff3, count: 5)

        let coefficient = coeff1 + coeff2 + coeff3

        let t1LSB = 31
        let t2LSB = 0
        let t3 = 2

        let p1LSB = 4
        let p2LSB = 6
        let p3 = 8
        let p4LSB = 10
        let p5LSB = 12
        let p7 = 14
        let p6 = 15
        let p8LSB = 18
        let p9LSB = 20
        let p10 = 22

        let h1LSB = 24
        let h1MSB = 25
        let h2LSB = 24
        let h2MSB = 23
        let h3 = 26
        let h4 = 27
        let h5 = 28
        let h6 = 29
        let h7 = 30

        let g2LSB = 33
        let g1 = 35
        let g3 = 36

        let heatVal = 37
        let heatRange = 39
        let rangeSWErr = 41

        let parT1 = calUInt16(coefficient, t1LSB)
        let parT2 = calInt16(coefficient, t2LSB)
        let parT3 = calInt8(coefficient, t3)
        tCoeff = [parT1, parT2, parT3]

        let parG1 = calInt8(coefficient, g1)
        let parG2 = calInt16(coefficient, g2LSB)
        let parG3 = calInt8(coefficient, g3)
        gCoeff = [parG1, parG2, parG3]

        let parH1 = Double(UInt16(coefficient[h1MSB]) << 4 |
                           UInt16(coefficient[h1LSB]) & 0x0f)
        let parH2 = Double(UInt16(coefficient[h2MSB]) << 4 |
                           UInt16(coefficient[h2LSB]) >> 4)
        let parH3 = calInt8(coefficient, h3)
        let parH4 = calInt8(coefficient, h4)
        let parH5 = calInt8(coefficient, h5)
        let parH6 = Double(coefficient[h6])
        let parH7 = calInt8(coefficient, h7)
        hCoeff = [parH1, parH2, parH3, parH4, parH5, parH6, parH7]

        let parP1 = calUInt16(coefficient, p1LSB)
        let parP2 = calInt16(coefficient, p2LSB)
        let parP3 = calInt8(coefficient, p3)
        let parP4 = calInt16(coefficient, p4LSB)
        let parP5 = calInt16(coefficient, p5LSB)
        let parP6 = calInt8(coefficient, p6)
        let parP7 = calInt8(coefficient, p7)
        let parP8 = calInt16(coefficient, p8LSB)
        let parP9 = calInt16(coefficient, p9LSB)
        let parP10 = Double(coefficient[p10])
        pCoeff = [parP1, parP2, parP3, parP4, parP5,
                  parP6, parP7, parP8, parP9, parP10]

        heatValue = calInt8(coefficient, heatVal)
        heaterRange = Double((coefficient[heatRange] & 0x30) >> 4)
        rangeSwitchingError = Double(Int8(
            truncatingIfNeeded: coefficient[rangeSWErr] & 0xF0) >> 4)
    }

    func calInt16(_ data: [UInt8] , _ lowIndex: Int) -> Double {
        let low = data[lowIndex]
        let high = data[lowIndex + 1]
        return Double(Int16(high) << 8 | Int16(low))
    }

    func calUInt16(_ data: [UInt8] , _ lowIndex: Int) -> Double {
        let low = data[lowIndex]
        let high = data[lowIndex + 1]
        return Double(UInt16(high) << 8 | UInt16(low))
    }

    func calInt8(_ data: [UInt8] , _ index: Int) -> Double {
        return Double(Int8(truncatingIfNeeded: data[index]))
    }

    private func readRawValues() -> [Double] {
        var data: [UInt8] = []

        mode = .force
        writeCtrlMeas()

        var newData = false
        while !newData {
            data = readRegister(.measStatus0, count: 15)

            let measStatus = data[0] & 0x80
            if measStatus != 0 {
                newData = true
            }
            sleep(ms: 5)
        }

        let rawPressure = Double(UInt32(data[2]) << 12 | UInt32(data[3]) << 4 |
                                 UInt32(data[4]) >> 4)
        let rawTemp = Double(UInt32(data[5]) << 12 | UInt32(data[6]) << 4 |
                             UInt32(data[7]) >> 4)
        let rawHum = Double(UInt16(data[8]) << 8 | UInt16(data[9]))
        let rawGas = Double(UInt16(data[13]) << 2 | UInt16(data[14]) >> 6)
        let gasRange = Double(data[14] & 0x0F)

        let value1 = (rawTemp / 16384 - tCoeff[0] / 1024) * tCoeff[1]
        let value2 = (rawTemp / 131072 - tCoeff[0] / 8192) *
        (rawTemp / 131072 - tCoeff[0] / 8192) * (tCoeff[2] * 16)

        let tFine = value1 + value2

        if rawTemp == 0x80000 {
            print("!!!!!!!!!!!")
        }

        return [rawPressure, rawTemp, rawHum, rawGas, gasRange, tFine]
    }
}
