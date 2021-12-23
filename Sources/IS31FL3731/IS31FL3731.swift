//=== IS31FL3731.swift ----------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Andy Liu
// Created: 07/29/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO

#if canImport(MadDisplay)
import struct MadDisplay.ColorSpace
#endif

/**
 This is the library for IS31FL3731 chip. It supports I2C communication.
 By default, you can use it with a 9x16 LED matrix.
 
 The LED matrix has 16 rows (X0 - X15), each row has 9 LEDs (Y0 - Y8).
 One LED stands for one pixel. The first LED labeled X0 and Y0 is the origin.
 There are two ways to indicate it: 0 or (0,0). Each LED has 8-bit grayscale,
 that is, 256 levels of brightness. 0 is off and 255 is full brightness.

 The display has 8 seperate frames from 0 to 7. You can show any of them or
 display in turns to create an animation.
 
 You can also regard the LED matrix as a 9x16 screen and use `MadDisplay`
 to display text on it.
 
 - Attention: If you set all pixels to full brightness, the module will require
 too much current. So you may need to connect an external power supply
 instead of the computer's USB port. And if you hear buzzing from it,
 don't worry, it's because it works quickly to switch LED on and off.
 */

public final class IS31FL3731 {
    
    private let i2c: I2C
    private let address: UInt8
    /// Width of the LED matrix. It's 16 by default.
    public let width: Int = 16
    /// Height of the LED matrix. It's 9 by default.
    public let height: Int = 9

    /// The current frame that the matrix displays or sets.
    public private(set) var currentFrame: UInt8 = 0
    
#if canImport(MadDisplay)
    public private(set) var colorSpace = ColorSpace()
#endif
    
    /**
     Initialize the module to get it ready for lighting.
     - Parameter i2c: **REQUIRED** The I2C interface that the module connects.
     - Parameter address: **OPTIONAL** The address of the module.
     */
    public init(i2c: I2C, address: UInt8 = 0x74) {
        
        self.i2c = i2c
        self.address = address
        
#if canImport(MadDisplay)
        colorSpace.depth = 8
        colorSpace.grayscale = true
#endif
        
        shutdown()
        stopBreath()
        setMode(.picutreMode)
        
        for frame in 0..<8 {
            selectPage(UInt8(frame))
            controlRegInit(true)
            blinkRegInit(true)
            fill()
        }
        setToFrame(Int(currentFrame))
        startup()
    }

    /// Change the current frame to a specified frame from 0 to 7.
    /// - Parameters:
    ///   - frame: The frame to be set or displayed.
    ///   - show: Whether to show the specified frame. By default, it's true
    ///     and the matrix show the frame.
    public func setToFrame(_ frame: Int, show: Bool = true) {
        guard frame < 8 && frame >= 0 else { return }
        currentFrame = UInt8(frame)
        selectPage(currentFrame)

        if show {
            writeRegister(.pictureDisplay, currentFrame)
        }
    }

    /// Make the preset LEDs to create a breathing effect.
    ///
    /// It will happen once. If you want the LEDs to breath continously, you
    /// can use it with `setAutoPlay`.
    public func startBreath() {
        writeRegister(.breathControl1, 0b0100_0100)
        writeRegister(.breathControl2, 0b0001_0100)
    }


    /// Display the frames in sequence from the first frame (frame0) in a
    /// designated pattern.
    ///
    /// You can set the number of frames from 0 to 7. If it's 0, all frames
    /// will be displayed. And 1-7 corresponds to a number of frames.
    /// For example, 3 means three frames, so the matrix displays frame0 to
    /// frames2 in sequence.
    ///
    /// The number of loops can be 0 to 7. 1-7 means the corresponding number
    /// of loops and 0 refers to an
    /// infinite loop.
    ///
    /// And the display speed is decided by the delay time. The maximum is
    /// around 700ms.
    /// - Parameters:
    ///   - frames: The number of frames from 0 to 7, all frames by default.
    ///   - delay: The delay time between frames in ms, 500 by default.
    ///   - loops: The number of loops from 0 to 7. By default the frames
    ///     loops endlessly.
    public func setAutoPlay(_ frames: Int = 0, delay: Int = 500,
                            loops: Int = 0) {
        var frames = frames
        var loops = loops
        let delay = delay / 11

        if frames > 7 || frames < 0 {
            frames = 0
        }
        if loops > 7 {
            loops = 0
        }

        if delay == 0 {
            setMode(.picutreMode)
        }

        let data = UInt8(loops) << 4 | UInt8(frames)
        let data2 = UInt8(delay % 64)

        writeRegister(.autoPlayControl, data)
        writeRegister(.autoPlayDelay, data2)
        setMode(.autoPlayMode)
    }
    
    /**
     Light an LED by telling its number from 0 to 143.
     The brightness of the LED can range from 0 (off) to 255 (full brightness).
     
     - Parameter number: The location of the LED from 0 to 143.
     - Parameter brightness: The brightness of the specified LED.
     By default, the LED is set to full brightness.
     */
    @inline(__always)
    public func writePixel(_ number: Int, brightness: UInt8 = 255) {
        guard number < width * height && number >= 0 else { return }
        let data = [UInt8(number) + Offset.pwm.rawValue, brightness]
        i2c.write(data, to: address)
    }
    
    /**
     Light an LED by telling its coordinates.
     The brightness of the LED can range from 0 (off) to 255 (full brightness).
     
     - Parameter x: The x coordinate of the LED.
     - Parameter y: The y coordinate of the LED.
     - Parameter brightness: The brightness of the specified LED.
     By default, the LED is set to full brightness.
     */
    @inline(__always)
    public func writePixel(x: Int, y: Int, brightness: UInt8 = 255) {

        guard x <= width && y <= height else { return }
        let reg = UInt8(y * width + x) + Offset.pwm.rawValue
        let data = [reg, brightness]
        i2c.write(data, to: address)
    }
    
    /**
     Set a part of the pixels on the matrix by defining the area.
     The area is a rectangle determined by a starting point, width and height.
     Then you can set the pixels to any brightness.
     
     - Parameter x: The horizontal line of the matrix to decide
     the start point, from 0 to 15.
     - Parameter y: The vertical line of the matrix to decide
     the start point, from 0 to 8.
     - Parameter width: The number of pixels horizontally.
     - Parameter height: The number of pixels vertically.
     - Parameter brightness: The brightness level of all pixels.
     Each byte stands for the brightness of each pixel.
     */
    public func writeBitmap(x: Int, y: Int, width: Int,
                            height: Int, data: [UInt8]
    ) {
        guard x < self.width && y < self.height
                && width >= 1 && height >= 1 else {
                    return
                }
        
        let bitmapWidth: Int, bitmapHeight: Int
        
        if x + width <= self.width {
            bitmapWidth = width
        } else {
            bitmapWidth = self.width - x
        }
        
        if y + height <= self.height {
            bitmapHeight = height
        } else {
            bitmapHeight = self.height - y
        }
        
        var rowData = [UInt8](repeating: 0x00, count: bitmapWidth + 1)
        
        for cY in y..<y + bitmapHeight {
            var rowPos = 1
            for cX in x..<x + bitmapWidth {
                let pos = (cY - y) * width + (cX - x)
                rowData[rowPos] = data[pos]
                rowPos += 1
            }
            rowData[0] = Offset.pwm.rawValue + UInt8(cY * self.width + x)
            i2c.write(rowData, to: address)
        }
    }
    
    
    /// Set all pixels to a specified brightness.
    /// - Parameter brightness: The level between 0 and 255.
    ///     By default, all LEDs are off.
    public func fill(_ brightness: UInt8 = 0x00) {
        var data = [UInt8](repeating: brightness, count: 144 + 1)
        data[0] = Offset.pwm.rawValue
        i2c.write(data, to: address)
    }
}

extension IS31FL3731 {

    private enum PageRegister: UInt8 {
        case command            = 0xFD
        case functionPage       = 0x0B
    }

    private enum FunctionRegister: UInt8 {
        case modeConfiguration  = 0x00
        case pictureDisplay     = 0x01
        case autoPlayControl    = 0x02
        case autoPlayDelay      = 0x03
        case displayOption      = 0x05
        case audioSync          = 0x06
        case frameState         = 0x07
        case breathControl1     = 0x08
        case breathControl2     = 0x09
        case shutdown           = 0x0A
        case AGCControl         = 0x0B
        case audioADCRate       = 0x0C
    }

    enum Mode: UInt8 {
        case picutreMode        = 0x00
        /// In auto play mode, the frame is 0 by default. So it's 0b01000.
        case autoPlayMode       = 0x08
    }

    private enum Offset: UInt8 {
        case ledControl = 0x00
        case blink = 0x12
        case pwm = 0x24
    }


    private func setMode(_ mode: Mode) {
        writeRegister(FunctionRegister.modeConfiguration, mode.rawValue)
    }

    private func selectPage(_ page: UInt8) {
        guard page < 8 || page == PageRegister.functionPage.rawValue else { return }
        let data = [PageRegister.command.rawValue, page]
        i2c.write(data, to: address)
    }

    
    private func writeRegister(_ register: FunctionRegister, _ value: UInt8) {
        selectPage(PageRegister.functionPage.rawValue)
        let data = [register.rawValue, value]
        i2c.write(data, to: address)
        selectPage(currentFrame)
    }
    
    private func readRegister(_ register: FunctionRegister) -> UInt8 {
        selectPage(PageRegister.functionPage.rawValue)
        i2c.write(register.rawValue, to: address)
        let ret = i2c.readByte(from: address)
        selectPage(currentFrame)

        switch ret {
        case .success(let byte):
            return byte
        case .failure(let err):
            print("error: \(#function) " + String(describing: err))
            return 0
        }
    }

    private func stopBreath() {
            writeRegister(.breathControl2, 0b0000_0000)
    }
    
    private func controlRegInit(_ value: Bool) {
        var data: [UInt8]
        
        if value {
            data = [UInt8](repeating: 0xFF, count: 0x12 + 1)
        } else {
            data = [UInt8](repeating: 0x00, count: 0x12 + 1)
        }
        
        data[0] = Offset.ledControl.rawValue
        i2c.write(data, to: address)
    }
    
    private func blinkRegInit(_ value: Bool) {
        var data: [UInt8]
        
        if value {
            data = [UInt8](repeating: 0xFF, count: 0x12 + 1)
        } else {
            data = [UInt8](repeating: 0x00, count: 0x12 + 1)
        }
        
        data[0] = Offset.blink.rawValue
        i2c.write(data, to: address)
    }
    
    private func startup() {
        writeRegister(FunctionRegister.shutdown, 1)
        sleep(ms: 10)
    }
    
    private func shutdown() {
        writeRegister(FunctionRegister.shutdown, 0)
        sleep(ms: 10)
    }
    
}


#if canImport(MadDisplay)
import protocol MadDisplay.BitmapWritable

extension IS31FL3731: BitmapWritable {
    
}

#endif
