//=== DHTxx.swift ---------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Jan Anstipp
// Created: 10/28/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//


import SwiftIO

/**
 The DHTxx class is driver for DHT11 and DHT22 modules. DHT modules are sensors
 for sensing relative humidity and temperature. These are digital sensors which
 use a single wire/bus protocol for communication.

 They consist of a humidity sensing component and thermistor. When the
 temperature or humidity changes, the corresponding components change their
 resistance.

 - Attention: The sampling rate should be no less than 1s for DHT11 and 2s
 for DHT22.

 */

public final class DHTxx {
    /**
     DigitalInOut pin id on the board.
     */
    private let signal: DigitalInOut
    
    /**
     Initialize a DHTxx signal to a specified pin.
     - parameter signal: **REQUIRED** The DigitalInOut pin id on the board.
     See Id for reference.
     */
    public init(_ signal: DigitalInOut){
        self.signal = signal
        signal.setToOutput(.pushPull, value: true)
        sleep(ms: 24)
    }

    /// Get the relative humidity and the temperature.
    /// - Returns: Two floats representing humidity and temperature respectively.
    public func readValues() -> (Float, Float)? {
        var data: (Float, Float)? = nil
        do {
            data = try readRawValue()
        } catch {
            print(error)
        }
        return data
    }

    /// Read the current temperature in Celcius.
    /// - Returns: Current temperature reading.
    public func readCelsius() -> Float? {
        var temperature: Float? = nil
        do {
            temperature = try readRawValue().1
        } catch {
            print(error)
        }
        return temperature
    }

    /// Read the relatice humidity.
    /// - Returns: Current humidity.
    public func readHumidity() -> Float? {
        var humidity: Float? = nil
        do {
            humidity = try readRawValue().0
        } catch {
            print(error)
        }
        return humidity
    }
}

extension DHTxx {

    /**
     Fetch data from DHT modul.
     - Returns: Data from DHT modul.
     */
    private func readRawValue() throws -> (Float, Float) {
        var dataBits: [Bool] = []

        /// MCU sends out start signal.
        signal.setToOutput(.pushPull, value: false)
        sleep(ms: 18)

        signal.setToInput(.pullUp)

        /// Pull up voltage and wait for the sensors's response, which lasts
        /// about 20-40us.
        _ = try edge(10000, 45000, false)

        /// Receive a low-level response signal from the sensor, which lasts
        /// about 80us.
        _ = try edge(75000, 100000, true)

        /// Receive a high-level signal from the sensor for about 80us which
        /// prepares the data transmission.
        _ = try edge(75000, 100000, false)

        /// Read and store the 40bit data:
        /// 8bit integral RH data, 8bit decimal RH data,
        /// 8bit integral T data, 8bit decimal T data,
        /// 8bit check sum.
        for _ in 0...39 {
            dataBits.append(try bit())
        }

        return try decode(bits: dataBits)
    }

    /// Calculate the duration of each signal.
    private func edge(_ min: Int64, _ max: Int64, _ value: Bool) throws -> Int64{
        let start = getClockCycle()

        while signal.read() != value {
            let time = cyclesToNanoseconds(start: start, stop: getClockCycle())
            if max < time {
                throw DHTError.EdgeTimeOut
            }
        }

        let edge = getClockCycle()
        let time = cyclesToNanoseconds(start: start, stop: edge)

        if time < min {
            throw DHTError.EdgeError
        }

        return time
    }

    /// Read and store the data bit from the sensor.
    private func bit() throws -> Bool {
        /// Receive the signal for about 50us before each bit of data.
        _ = try edge(45000, 55000, true)

        let time = try edge(15000, 80000, false)

        /// The signal for bit "0" is around 26-28us.
        /// The signal for bit "1" is around 70us.
        if( time > 15000 && time < 37000 ){
            return false
        }
        else if time > 65000 && time < 80000 {
            return true
        }
        throw DHTError.BitError
    }


    /// Decode the bits into final readings.
    /// The first value is the humidity and the second is temperature.
    private func decode(bits: [Bool]) throws -> (Float, Float) {
        var bytes: [UInt8] = [0,0,0,0,0]
        for i in 0..<40 {
            bytes[i/8] <<= 1
            if bits[i] {
                bytes[i/8] |= 1
            }
        }

        var check: UInt8 = 0
        for i in 0...3{
            check = check.addingReportingOverflow(bytes[i]).partialValue
        }

        if (bytes[4] != check) {
            throw DHTError.DecodingError
        }

        return (Float("\(bytes[0]).\(bytes[1])")!,
                Float("\(bytes[2]).\(bytes[3])")!)
    }

    private enum DHTError: Error {
        case ResponseTimeOut
        case EdgeTimeOut
        case EdgeError
        case BitError
        case DecodingError
    }
}
