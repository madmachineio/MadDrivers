//=== HCSR04.swift --------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 10/21/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for HCSR40 ultrasonic sensor used to measure distance.
///
/// During its work, the sensor will send an ultrasonic signal and
/// receive the reflected signal. You can get a round-trip time.
/// The sound speed in the air is 343m/s.
/// Then you can calculate the distance in-between.
///
/// - Attention: Make sure to use the sensor that requires 3.3V,
/// or it might return a wrong value and even do damage to your board.
final public class HCSR40 {
    private let trig: DigitalOut
    private let echo: DigitalIn
    
    /// Initialize an ultrasonic sensor.
    /// You need to use two digital pins to send and receive signal.
    /// Then you set a maximum time to wait for the signal to
    /// avoid too long a distance or any unexpected situation.
    /// - Parameters:
    ///   - trig: **REQUIRED** A DigitalOut pin used to output a pulse.
    ///   - echo: **REQUIRED** A DigitalIn pin used to read the pulse.
    ///   - timeout: **OPTIONAL** A preset time to wait for the response.
    ///     0.1s by default.
    public init(trig: DigitalOut, echo: DigitalIn) {
        self.trig = trig
        self.echo = echo
    }

    /// Measure the distance between the sensor and the object in meters.
    /// - Returns: A float representing the distance in meters.
    public func measure(timeout: Float = 0.1) -> Float? {
        trig.high()
        wait(us: 10)
        trig.low()

        let start = getClockCycle()
        var distance: Float = 0

        while !echo.read() {
            let currentTime = getClockCycle()
            let time = Float(cyclesToNanoseconds(
                start: start, stop: currentTime)) / 1_000_000_000
            if time > timeout {
                return nil
            }
        }

        while echo.read() {

        }

        let currentTime = getClockCycle()
        let time = Float(cyclesToNanoseconds(
            start: start, stop: currentTime)) / 1_000_000_000
        distance = time * 343 / 2.0
        return distance
    }
}

