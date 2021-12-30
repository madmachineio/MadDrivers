//=== LCD1602.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Andy Liu
// Created: 06/13/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

/// This is the library for LCD1602 character display included in the Maker kit.
///
/// The LCD1602 means it has 2 rows and 16 characters per row, 32 characters
/// in total. The first dot matrix on the upper left is the origin (0, 0) of
/// the LCD. You can decide the location of your text using the coordinate
/// (0, 0) to (15, 1) on the LCD. It communicates with your board using
/// I2C interface.
final public class LCD1602 {
    
    private enum Command: UInt8 {
        case clearDisplay   = 0x01
        case returnHome     = 0x02
        case entryModeSet   = 0x04
        case displayControl = 0x08
        case cursorShift    = 0x10
        case functionSet    = 0x20
        case setCGRAMAddr   = 0x40
        case setDDRAMAddr   = 0x80
    }
    
    private struct FunctionMode: OptionSet {
        let rawValue: UInt8
        
        static let _4BitMode = FunctionMode([])
        static let _8BitMode = FunctionMode(rawValue: 0x10)
        
        static let _1Line = FunctionMode([])
        static let _2Line = FunctionMode(rawValue: 0x08)
        
        static let _5x8Dots = FunctionMode([])
        static let _5x10Dots = FunctionMode(rawValue: 0x04)
    }
    
    private struct ControlMode: OptionSet {
        let rawValue: UInt8
        
        static let displayOff = ControlMode([])
        static let displayOn = ControlMode(rawValue: 0x04)
        
        static let cursorOff = ControlMode([])
        static let cursorOn = ControlMode(rawValue: 0x02)
        
        static let blinkOff = ControlMode([])
        static let blinkOn = ControlMode(rawValue: 0x01)
    }
    
    private struct EntryMode: OptionSet {
        let rawValue: UInt8
        
        static let entryRight = EntryMode([])
        static let entryLeft = EntryMode(rawValue: 0x02)
        
        static let entryShiftDecrement = EntryMode([])
        static let entryShiftIncrement = EntryMode(rawValue: 0x01)
    }
    
    private struct ShiftMode: OptionSet {
        let rawValue: UInt8
        
        static let cursorMove = ShiftMode([])
        static let displayMove = ShiftMode(rawValue: 0x08)
        
        static let moveLeft = ShiftMode([])
        static let moveRight = ShiftMode(rawValue: 0x04)
    }
    
    let i2c: I2C
    let address: UInt8
    
    private var funntionModeConfig: FunctionMode
    private var controlModeConfig: ControlMode
    private var entryModeConfig: EntryMode
    private var shiftModeConfig: ShiftMode


    /// Initialize the LCD using I2C communication.
    /// - Parameters:
    ///   - i2c: **REQUIRED** The I2C interface that the module connects.
    ///   - address: **OPTIONAL** The sensor's address.
    ///   - columns: **OPTIONAL** The number of columns, 16 by default.
    ///   - rows: **OPTIONAL** The number of rows, 2 by default.
    ///   - dotSize: **OPTIONAL** The height of a dot matrix for a character.
    public init(_ i2c: I2C, address: UInt8 = 0x3E,
                columns: UInt8 = 16, rows: UInt8 = 2, dotSize: UInt8 = 8) {
        
        guard (columns > 0) && (rows == 1 || rows == 2)
                && (dotSize == 8 || dotSize == 10) else {
            fatalError("LCD1602 parameter error, init failed")
        }
        
        self.i2c = i2c
        self.address = address
        
        funntionModeConfig = FunctionMode([])
        controlModeConfig = ControlMode([.displayOn, .cursorOff, .blinkOff])
        entryModeConfig = EntryMode([.entryLeft, .entryShiftDecrement])
        shiftModeConfig = ShiftMode([])
        
        if rows > 1 {
            funntionModeConfig.insert(._2Line)
        }
        
        if dotSize != 8 && rows == 1 {
            funntionModeConfig.insert(._5x10Dots)
        }
        
        writeConfig(funntionModeConfig, to: .functionSet)
        sleep(ms: 5)
        
        writeConfig(funntionModeConfig, to: .functionSet)
        sleep(ms: 1)
        
        writeConfig(funntionModeConfig, to: .functionSet)
        writeConfig(funntionModeConfig, to: .functionSet)
        
        leftToRight()
        noAutoScroll()
        clear()
        turnOn()
    }

    /// Clear the display and set cursor to the origin (0, 0).
    public func clear() {
        writeCommand(.clearDisplay)
        sleep(ms: 2)
    }

    /// Move the cursor to the origin (0, 0).
    public func home() {
        writeCommand(.returnHome)
        sleep(ms: 2)
    }

    /// Turn on the display.
    public func turnOn() {
        controlModeConfig.insert(.displayOn)
        controlModeConfig.remove(.displayOff)
        writeConfig(controlModeConfig, to: .displayControl)
    }

    /// Turn off the display.
    public func turnOff() {
        controlModeConfig.insert(.displayOff)
        controlModeConfig.remove(.displayOn)
        writeConfig(controlModeConfig, to: .displayControl)
    }

    /// Show the cursor on the LCD.
    public func cursorOn() {
        controlModeConfig.insert(.cursorOn)
        controlModeConfig.remove(.cursorOff)
        writeConfig(controlModeConfig, to: .displayControl)
    }

    /// Hide the cursor on the LCD.
    public func cursorOff() {
        controlModeConfig.insert(.cursorOff)
        controlModeConfig.remove(.cursorOn)
        writeConfig(controlModeConfig, to: .displayControl)
    }

    /// Display blinking cursor on the LCD.
    public func cursorBlinkOn() {
        controlModeConfig.insert(.blinkOn)
        controlModeConfig.remove(.blinkOff)
        writeConfig(controlModeConfig, to: .displayControl)
    }

    /// Turn off the blinking cursor on the LCD.
    public func cursorBlinkOff() {
        controlModeConfig.insert(.blinkOff)
        controlModeConfig.remove(.blinkOn)
        writeConfig(controlModeConfig, to: .displayControl)
    }

    /// Set the direction of the text on the screen from left to right.
    /// The text that has been displayed won't change, so you need to set it
    /// before writing a new text.
    public func leftToRight() {
        entryModeConfig.insert(.entryLeft)
        entryModeConfig.remove(.entryRight)
        writeConfig(entryModeConfig, to: .entryModeSet)
    }

    /// Set the direction of the text on the screen from right to left.
    /// The text that has been displayed won't change, so you need to set it
    /// before writing a new text.
    public func rightToLeft() {
        entryModeConfig.insert(.entryRight)
        entryModeConfig.remove(.entryLeft)
        writeConfig(entryModeConfig, to: .entryModeSet)
    }

    /// Move automatically each letter or number writen to the LCD by one step.
    /// If text is from left to right, the scrolling would be towards the left,
    /// and vice versa.
    public func autoScroll() {
        entryModeConfig.insert(.entryShiftIncrement)
        entryModeConfig.remove(.entryShiftDecrement)
        writeConfig(entryModeConfig, to: .entryModeSet)
    }

    /// Turn off the autoscroll.
    public func noAutoScroll() {
        entryModeConfig.insert(.entryShiftDecrement)
        entryModeConfig.remove(.entryShiftIncrement)
        writeConfig(entryModeConfig, to: .entryModeSet)
    }

    /// Scroll the text one step to the left.
    public func scrollLeft() {
        shiftModeConfig.insert([.displayMove, .moveLeft])
        shiftModeConfig.remove([.cursorMove, .moveRight])
        writeConfig(shiftModeConfig, to: .cursorShift)
    }

    /// Scroll the text one step to the right.
    public func scrollRight() {
        shiftModeConfig.insert([.displayMove, .moveRight])
        shiftModeConfig.remove([.cursorMove, .moveLeft])
        writeConfig(shiftModeConfig, to: .cursorShift)
    }

    /// Clear some specified dot matrixes on the LCD.
    /// - Parameters:
    ///   - x: The x-coordinate of the dot matrix.
    ///   - y: The y-coordinate of the dot matrix.
    ///   - count: The number of matrix from the specified x-coordinate to be cleared.
    public func clear(x: Int, y: Int, count: Int = 1) {
        guard count > 0 else {
            return
        }
        
        let data: [UInt8] = [0x40, 0x20]
        
        setCursor(x: x, y: y)
        for _ in 1...count {
            i2c.write(data, to: address)
        }
        setCursor(x: x, y: y)
    }

    /// Move the cursor to a specified position.
    /// - Parameters:
    ///   - x: The x-coordinate to position the cursor.
    ///   - y: The y-coordinate to position the cursor.
    public func setCursor(x: Int, y: Int) {
        guard x >= 0 && y >= 0 else { 
            return
        }
        let val: UInt8 = y == 0 ? UInt8(x) | 0x80 : UInt8(x) | 0xc0
        writeCommand(val)
    }

    /// Write a string on the LCD at a specified location.
    /// - Parameters:
    ///   - x: The x coordinate of the LCD to display the string.
    ///   - y: The y coordinate of the LCD to display the string.
    ///   - str: The string that will display on the LCD.
    public func write(x: Int, y: Int, _ str: String) {
        setCursor(x: x, y: y)
        writeData(str)
    }

    /// Display a number on the LCD at a specified location.
    /// - Parameters:
    ///   - x: The x coordinate of the LCD to display the number.
    ///   - y: The y coordinate of the LCD to display the number.
    ///   - num: The number that will display on the LCD.
    public func write(x: Int, y: Int, _ num: Int) {
        write(x: x, y: y, String(num))
    }

    /// Round a given float to the specified number of decimal places and
    /// display it on the LCD.
    /// - Parameters:
    ///   - x: The x-coordinate of the LCD to display the number.
    ///   - y: The y-coordinate of the LCD to display the number.
    ///   - num: A float.
    ///   - decimal: The specified number of decimal places.
    public func write(x: Int, y: Int, _ num: Float, decimal: Int? = 1) {
        if let decimal = decimal {
            if decimal <= 0 {
                write(x: x, y: y, String(Int(num)))
                return
            }
            
            var mul = 1
            for _ in 0..<decimal {
                mul *= 10
            }
            let expandValue = Int(num * Float(mul))
            write(x: x, y: y, String(Float(expandValue) / Float(mul)))
        } else {
            write(x: x, y: y, String(num))
        }
    }
}

extension LCD1602 {
    
    private func writeCommand(_ command: Command) {
        writeCommand(command.rawValue)
    }
    
    private func writeCommand(_ value: UInt8) {
        let data: [UInt8] = [0x80, value]
        i2c.write(data, to: address)
    }
    
    private func writeConfig<T: OptionSet>(_ config: T, to command: Command) {
        let value = config.rawValue as? UInt8
        guard  value != nil else {
            return
        }
        writeCommand(value! | command.rawValue)
    }
    
    private func writeData(_ str: String) {
        let bytes: [UInt8] = Array(str.utf8)
        var data: [UInt8] = [0x40, 0]
        
        for byte in bytes {
            data[1] = byte
            i2c.write(data, to: address)
        }
    }
}
