//=== APDS9960.swift ------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Ines Zhou
// Created: 01/06/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for APDS9960 proximity, ambient light, color and gesture
/// Sensor.
///
/// The APDS9960 has an integrated IR LED and four directional (up, down, left,
/// right) photodiodes to sense reflected IR energy. When some gestures are
/// performed, the IR energy would reflect back to the sensor. The sensor could
/// know the gesture and distance from the light. As for color detection, the
/// sensor has UV and IR blocking filters and finally provide 16-bit data for red,
/// green, blue and clear.
final public class APDS9960 {
    private let i2c: I2C
    private let address: UInt8
    private let rotation: Rotation

    var readBuffer = [UInt8](repeating: 0, count: 32 * 4)

    /// Initialize the sensor using I2C communication.
    ///
    /// - Parameters:
    ///   - i2c: **REQUIRED** An I2C interface for the communication. The maximum
    ///   I2C speed is 400KHz.
    ///   - address: **OPTIONAL** The sensor's address. 0x39 by default.
    ///   - rotation: **OPTIONAL** The degree clockwise the sensor is rotated.
    ///   An rotation offset will be applied when reading the gesture.
    public init(_ i2c: I2C, address: UInt8 = 0x39,
                rotation: Rotation = .degree0) {
        self.i2c = i2c
        self.address = address
        self.rotation = rotation

        guard (i2c.getSpeed() == .standard) || (i2c.getSpeed() == .fast) else {
            fatalError(#function + ": APDS9960 only supports 100kHz (standard) and 400kHz (fast) I2C speed")
        }

        guard getDeviceID() == 0xAB else {
            fatalError(#function + ": Fail to find APDS9960 at address \(address)")
        }
        
        setColorGain(.x4)
        setColorIntegrationTime(200)

        disableGesture()
        disableColor()
        disableProximity()

        disableColorInterrupt()
        disableProximityInterrupt()
        clearInterrupt()

        disable()
        sleep(ms: 10)
        enable()
        sleep(ms: 10)

        setGestureDimensions(.all)
        setGestureFIFOThreshold(.threshold4)
        setGestureGain(.x4)
        setGPThreshold(0)
        setGPulse(length: .us32, count: 9)

    }

    /// Read red, green, blue, clear color data. Make sure to enable the color
    /// detection first.
    ///
    /// The maximum data is decided by integration time. By default, the maximum
    /// is 65535.
    /// - Returns: The red, green, blue, clear color data.
    public func readColor() -> (red: UInt16, green: UInt16,
                                blue: UInt16, clear: UInt16) {

        while !isColorValid() {
            sleep(ms: 5)
        }

        try? readRegister(.cDataL, into: &readBuffer, count: 8)

        let clear = UInt16(readBuffer[0]) | (UInt16(readBuffer[1]) << 8)
        let red = UInt16(readBuffer[2]) | (UInt16(readBuffer[3]) << 8)
        let green = UInt16(readBuffer[4]) | (UInt16(readBuffer[5]) << 8)
        let blue = UInt16(readBuffer[6]) | (UInt16(readBuffer[7]) << 8)

        return (red, green, blue, clear)
    }

    /// Read proximity data. The closer the object, the higher the data.
    /// Make sure to enable the proximity detection first.
    ///
    /// Note: it just shows how the proximity changes, you cannot calculate
    /// the actual distance in meters between the sensor and the object.
    /// - Returns: The proximity data from 0 to 255.
    public func readProximity() -> UInt8 {
        var byte: UInt8 = 0
        try? readRegister(.pData, into: &byte)
        return byte
    }

    /// Read gestures. You need to enable both gesture and proximity detection
    /// before reading from the sensor.
    /// - Returns: The direction of the gesture: `.up`, `.down`, `.right`, `.left`.
    public func readGesture() -> Gesture {
        var gesture = calculateGesture()
        if gesture != .noGesture && self.rotation != .degree0 {
            gesture = rotatedGesture(gesture)
        }

        return gesture
    }

    /// Enable the color detection.
    public func enableColor() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)
        try? writeRegister(.enable, byte | 0b10)
    }

    /// Enable the proximity detection.
    public func enableProximity() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)
        try? writeRegister(.enable, byte | 0b100)
    }

    /// Enable the gesture detection.
    public func enableGesture() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)
        try? writeRegister(.enable, byte | 0b0100_0000)
    }

    /// Set the integration time of internal color analog to digital converters.
    /// The time is from 2.78 to 712ms.
    /// It decides the maximum count value for the color detection.
    /// The maximum is the lesser of 65535 and the result of 1025x(time/2.78).
    /// - Parameter time: The integration time from 2.78 to 712ms.
    public func setColorIntegrationTime(_ time: Float) {
        guard time <= 712 && time >= 2.78 else { return }
        let cycle = time / 2.78
        let value = UInt8(min(255, UInt8(256 - cycle)))
        try? writeRegister(.integrationTime, value)
    }

    /// The degree clockwise of the sensor. An offset will be applied when
    /// calculating the gesture.
    public enum Rotation: Int {
        case degree0 = 0
        case degree90 = 90
        case degree180 = 180
        case degree270 = 270
    }

    /// The gesture that the sensor detects.
    public enum Gesture: Int {
        case noGesture = 0
        case up = 1
        case down = 2
        case left = 3
        case right = 4
    }
}



extension APDS9960 {
    private enum Register: UInt8 {
        case enable = 0x80
        case integrationTime = 0x81
        case control1 = 0x8F
        case id = 0x92
        case status = 0x93
        case cDataL = 0x94
        case pData = 0x9C
        case gPENTH = 0xA0
        case gConfig1 = 0xA2
        case gConfig2 = 0xA3
        case gPulse = 0xA6
        case gConfig3 = 0xAA
        case gConfig4 = 0xAB
        case gFLVL = 0xAE
        case gStatus = 0xAF
        case allClear = 0xE7
        case gFIFOU = 0xFC
    }

    /// Sets the gain of the proximity receiver in gesture mode.
    enum GGain: UInt8 {
        case x1 = 0
        case x2 = 0x01
        case x4 = 0x02
        case x8 = 0x03
    }

    /// Sets the gain of the proximity receiver in gesture mode.
    enum CGain: UInt8 {
        case x1 = 0
        case x4 = 0x01
        case x16 = 0x02
        case x64 = 0x03
    }

    /// Gesture Pulse length.
    enum GPluseLength: UInt8 {
        case us4 = 0
        case us8 = 0x01
        case us16 = 0x02
        case us32 = 0x03
    }

    /// Select which pair of gesture photodiode are enabled.
    enum GestureDimension: UInt8 {
        case all = 0
        case upDown = 0x01
        case leftRight = 0x02
    }

    enum GFIFOThreshold: UInt8 {
        /// Interrupt is generated after 1 dataset is added to FIFO.
        case threshold1 = 0
        /// Interrupt is generated after 4 dataset is added to FIFO.
        case threshold4 = 0x01
        /// Interrupt is generated after 8 dataset is added to FIFO
        case threshold8 = 0x02
        /// Interrupt is generated after 16 dataset is added to FIFO
        case threshold16 = 0x03
    }


    private func writeValue(_ register: Register) throws {
        let result = i2c.write(register.rawValue, to: address)
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

    private func readRegister(_ register: Register, into byte: inout UInt8) throws {
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


    func getDeviceID() -> UInt8 {
        var byte: UInt8 = 0
        try? readRegister(.id, into: &byte)
        return byte
    }

    func enable() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)
        try? writeRegister(.enable, byte | 0b01)
    }

    func disable() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)
        try? writeRegister(.enable, byte & 0b1111_1110)
    }

    func disableColor() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)
        try? writeRegister(.enable, byte & 0b1111_1101)
    }

    func disableProximity() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)
        try? writeRegister(.enable, byte & 0b1111_1011)
    }

    func disableGesture() {
        var byte: UInt8 = 0
        try? readRegister(.gConfig4, into: &byte)
        try? writeRegister(.gConfig4, byte & 0b1111_1110)

        try? readRegister(.enable, into: &byte)
        try? writeRegister(.enable, byte & 0b1011_1111)
    }

    func enableProximityInterrupt() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)
        try? writeRegister(.enable, byte | 0b0010_0000)
    }

    func disableProximityInterrupt() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)
        try? writeRegister(.enable, byte & 0b1101_1111)
    }

    func enableColorInterrupt() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)
        try? writeRegister(.enable, byte | 0b0001_0000)
    }

    func disableColorInterrupt() {
        var byte: UInt8 = 0
        try? readRegister(.enable, into: &byte)
        try? writeRegister(.enable, byte & 0b1110_1111)
    }


    func setColorGain(_ gain: CGain) {
        var byte: UInt8 = 0
        try? readRegister(.control1, into: &byte)
        try? writeRegister(.control1, byte & 0b1111_1100 | gain.rawValue)
    }

    func setGestureGain(_ gain: GGain) {
        var byte: UInt8 = 0
        try? readRegister(.gConfig2, into: &byte)
        try? writeRegister(.gConfig2, byte & 0b1001_1111 | (gain.rawValue << 5))
    }

    func setGestureFIFOThreshold(_ threshold: GFIFOThreshold) {
        var byte: UInt8 = 0
        try? readRegister(.gConfig1, into: &byte)
        try? writeRegister(.gConfig1, byte & 0b0011_1111 | (threshold.rawValue << 6))
    }



    /// Length is gesture pulse length.
    /// Count is from 0 to 63. The number of gesture pulses is count plus 1.
    func setGPulse(length: GPluseLength, count: UInt8) {
        try? writeRegister(.gPulse, length.rawValue << 6 | count)
    }

    /// Set the proximity threshold value to activate the gesture detection.
    func setGPThreshold(_ threshold: UInt8) {
        try? writeRegister(.gPENTH, threshold)
    }

    func setGestureDimensions(_ dimension: GestureDimension) {
        try? writeRegister(.gConfig3, dimension.rawValue)
    }

    func clearInterrupt() {
        try? writeValue(.allClear)
    }

    func getGAvailable() -> UInt8 {
        var byte: UInt8 = 0
        try? readRegister(.gFLVL, into: &byte)
        return min(byte * 4, 32 * 4)
    }

    func isGestureValid() -> Bool {
        var byte: UInt8 = 0
        try? readRegister(.gStatus, into: &byte)
        return (byte & 0b1) == 1
    }

    func isColorValid() -> Bool {
        var byte: UInt8 = 0
        try? readRegister(.status, into: &byte)
        return byte & 0b1 == 1
    }

    func readRawGesture() -> [UInt8] {
        sleep(ms: 30)

        let count = getGAvailable()
        if count > 0 {
            try? readRegister(.gFIFOU, into: &readBuffer, count: Int(count))
        }
        return [readBuffer[0], readBuffer[1], readBuffer[2], readBuffer[3]]
    }

    func calculateGesture() -> Gesture {
        if isGestureValid() == false {
            return .noGesture
        }

        var time: UInt = 0
        var gesture: Gesture = .noGesture

        var detected = false
        var upStart = false
        var downStart = false
        var leftStart = false
        var rightStart = false

        while detected == false {
            var diffUpDown = 0
            var diffLeftRight = 0

            let data = readRawGesture()
            let up = Int(data[0])
            let down = Int(data[1])
            let left =  Int(data[2])
            let right = Int(data[3])

            if abs(up - down) > 13 {
                diffUpDown = up - down
            }

            if abs(left - right) > 13 {
                diffLeftRight = left - right
            }

            if diffUpDown < 0 {
                if upStart {
                    gesture = .up
                } else {
                    downStart = true
                }
            } else if diffUpDown > 0 {
                if downStart {
                    gesture = .down
                } else {
                    upStart = true
                }
            }

            if diffLeftRight < 0 {
                if leftStart {
                    gesture = .left
                } else {
                    rightStart = true
                }
            } else if diffLeftRight > 0 {
                if rightStart {
                    gesture = .right
                } else {
                    leftStart = true
                }
            }

            if (diffUpDown != 0) || (diffLeftRight != 0) {
                time = getClockCycle()
            }

            if gesture != .noGesture ||
                (cyclesToNanoseconds(start: UInt(time), stop: getClockCycle()) / 1_000_000) > 300 {
                detected = true
            }
        }

        return gesture
    }

    func rotatedGesture(_ gesture: Gesture) -> Gesture {
        let directions = [1, 4, 2, 3]
        let index = (directions.firstIndex(of: gesture.rawValue)! + rotation.rawValue / 90) % 4
        return Gesture(rawValue: directions[index])!
    }
}
