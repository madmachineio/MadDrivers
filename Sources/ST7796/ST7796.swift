//=== ST7796.swift --------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Andy Liu
// Created: 04/27/2024
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO


/// This is the library for ST7796 SPI screen.
/// It supports the size of screen: 480x320.
///
/// It has 16-bit color pixels. One pixel matches one point of the
/// coordinate system on the screen. It starts from (0,0).
/// The origin of the display is on the top left corner by default.
/// x and y coordinates go up respectively to the right and downwards.
/// The origin can also be changed to any of the four corners of the screen
/// as you rotate the display.
public final class ST7796 {
    
    /// The rotation angles of the screen.
    public enum Rotation {
        case angle0, angle90, angle180, angle270
    }

    private let initConfigs: [(address: Command, data: [UInt8]?)] = [
        (.CSCON, [0xC3]),
        (.CSCON, [0x96]),
        (.COLMOD, [0x55]),
        (.CSCON, [0x3C]),
        (.CSCON, [0x69]),
        // (.INVON, nil),
        (.DISPON, nil)
    ]
    
    //  private let initConfigs: [(address: Command, data: [UInt8]?)] = [
    //     (.CSCON, [0xC3]),
    //     (.CSCON, [0x96]),
    //     (.COLMOD, [0x05]),

    //     (.DOCA, [0x40, 0x82, 0x07, 0x18, 0x27, 0x0A, 0xB6, 0x33]),
    //     (.VCMPCTL, [0x27]),
    //     (.PWR3, [0xA7]),

    //     (.PGC, [0xF0, 0x01, 0x06, 0x0F, 0x12, 0x1D, 0x36, 0x54,
    //         0x44, 0x0C, 0x18, 0x16, 0x13, 0x15]),
    //     (.NGC, [0xF0, 0x01, 0x05, 0x0A, 0x0B, 0x07, 0x32, 0x44,
    //         0x44, 0x0C, 0x18, 0x17, 0x13, 0x16]),

    //     (.CSCON, [0x3C]),
    //     (.CSCON, [0x69]),

    //     //(.INVON, nil),
    //     (.DISPON, nil)
    //  ]

    let spi: SPI
    let cs, dc, rst, bl: DigitalOut
    
    private(set) var rotation: Rotation
    
    public private(set) var width: Int
    public private(set) var height: Int
    
    private var xOffset: Int
    private var yOffset: Int

    
    /// Initialize all the necessary pins and set the parameters of the screen.
    /// The ST7796 chip can drive 480x320 screen.
    /// - Parameters:
    ///   - spi: **REQUIRED** SPI interface. The communication speed between
    ///     two devices should be as fast as possible within the range,
    ///     usually 30,000,000.
    ///   - cs: **REQUIRED** The digital output pin used for chip select.
    ///   - dc: **REQUIRED** The digital output pin used for data or command.
    ///   - rst: **REQUIRED** The digital output pin used to reset the screen.
    ///   - bl: **REQUIRED** The digital output pin used for backlight control.
    ///   - width: **OPTIONAL** The width of the screen. It is 480 by default.
    ///   - height: **OPTIONAL** The height of the screen. It is 320 by default.
    ///   - rotation: **OPTIONAL** Set the origin and rotation of the screen.
    ///     By default, the origin is on top left of the screen.
    public init(spi: SPI, cs: DigitalOut, dc: DigitalOut,
                rst: DigitalOut, bl: DigitalOut,
                width: Int = 480, height: Int = 320,
                rotation: Rotation = .angle0) {
        guard (width == 480 && height == 320)
                || (width == 320 && height == 480)
                else {
                    print("Not support this resolution!")
                    fatalError()
                }
        
        self.spi = spi
        self.cs = cs
        self.dc = dc
        self.rst = rst
        self.bl = bl
        self.width = width
        self.height = height
        self.rotation = rotation
        self.xOffset = 0
        self.yOffset = 0
        
        reset()
        
        initConfigs.forEach { config in
            writeConfig(config.data, to: config.address)
        }
        setRoation(rotation)
        
        clearScreen()
        bl.high()
    }
    
    
    /// Change the orientation of the display and set the origin of the
    /// coordinate system. The rotation angle has four choices, which
    /// correspond to the four corners on the screen.
    /// - Parameter angle: The rotation angle.
    public func setRoation(_ angle: Rotation) {
        rotation = angle
        var madctlConfig: MadctlConfig = [.RGB]
        let ratio = (width, height)

        switch ratio {
            case (320, 480):
                xOffset = 0
                yOffset = 0
                switch rotation {
                case .angle0:
                    madctlConfig = [.pageTopToBottom, .rightToLeft,
                                    .normalMode, .lineTopToBottom, .BGR]
                case .angle90:
                    swap(&width, &height)
                    madctlConfig = [.pageTopToBottom, .leftToRight,
                                    .reverseMode, .lineTopToBottom, .BGR]
                case .angle180:
                    madctlConfig = [.pageBottomToTop, .leftToRight,
                                    .normalMode, .lineTopToBottom, .BGR]
                case .angle270:
                    swap(&width, &height)
                    madctlConfig = [.pageBottomToTop, .rightToLeft,
                                    .reverseMode, .lineTopToBottom, .BGR]
                }
            case (480, 320):
                xOffset = 0
                yOffset = 0
                switch rotation {
                case .angle0:
                    madctlConfig = [.pageTopToBottom, .leftToRight,
                                    .reverseMode, .lineTopToBottom, .BGR]
                case .angle90:
                    swap(&width, &height)
                    madctlConfig = [.pageBottomToTop, .leftToRight,
                                    .normalMode, .lineTopToBottom, .BGR]
                case .angle180:
                    madctlConfig = [.pageBottomToTop, .rightToLeft,
                                    .reverseMode, .lineTopToBottom, .BGR]
                case .angle270:
                    swap(&width, &height)
                    madctlConfig = [.pageTopToBottom, .rightToLeft,
                                    .normalMode, .lineTopToBottom, .BGR]
                }
            default:
                break
        }
        
        writeConfig([madctlConfig.rawValue], to: .MADCTL)
    }
    
    /// Write a single pixel on the screen by telling its position and color.
    /// - Parameters:
    ///   - x: The x-coordinate.
    ///   - y: The y-coordinate.
    ///   - color: The UInt16 color value.
    @inline(__always)
    public func writePixel(x: Int, y: Int, color: UInt16) {
        setAddrWindow(x: x, y: y, width: 1, height: 1)
        writeData([color], count: 1)
    }

    /// Set an area of pixels on the screen.
    /// - Parameters:
    ///   - x: The x-coordinate of the start point.
    ///   - y: The y-coordinate of the start point.
    ///   - w: The width of the area.
    ///   - h: The height of the area.
    ///   - data: An array of color data in UInt16.
    public func writeBitmap(x: Int, y: Int, width w: Int,
                            height h: Int, data: [UInt16]) {
        guard data.count >= w * h else { return }
        setAddrWindow(x: x, y: y, width: w, height: h)
        writeData(data, count: w * h)
    }

    /// Set an area of pixels on the screen. The data is in UInt8,
    /// while a pixel needs a UInt16. So every 2 data in the array set 1 pixel.
    /// - Parameters:
    ///   - x: The x-coordinate of the start point.
    ///   - y: The y-coordinate of the start point.
    ///   - w: The width of the area.
    ///   - h: The height of the area.
    ///   - data: An raw buffer of color data.
    public func writeBitmap(x: Int, y: Int, width w: Int,
                            height h: Int, data: UnsafeRawBufferPointer) {
        guard data.count >= w * h * 2 else { return }
        setAddrWindow(x: x, y: y, width: w, height: h)
        writeData(data, count: w * h * 2)
    }
    
    /// Set the screen with colors defined in an array.
    /// the product of width and height to set all pixels.
    /// - Parameter data: An array of color data in UInt16.
    public func writeScreen(_ data: [UInt16]) {
        guard data.count >= width * height else { return }
        setAddrWindow(x: 0, y: 0, width: width, height: height)
        writeData(data, count: width * height)
    }
    
    /// Set the screen with colors defined in an buffer.
    /// Two data are for one pixel. So the data count should be double
    /// the product of width and height to set all pixels.
    /// - Parameter data: An array of color data in UInt8.
    public func writeScreen(_ data: UnsafeRawBufferPointer) {
        guard data.count >= width * height * 2 else { return }
        setAddrWindow(x: 0, y: 0, width: width, height: height)
        writeData(data, count: width * height * 2)
    }
    
    /// Paint the whole screen with a specified color.
    /// - Parameter color: A 16-bit color value, by default, black.
    public func clearScreen(_ color: UInt16 = 0x0000) {
        let data = [UInt16](repeating: color, count: width * height)

        data.withUnsafeBytes { ptr in
            writeScreen(ptr)
        }
    }
    
    
    /// Reset the screen.
    public func reset() {
        cs.high()
        rst.low()
        sleep(ms: 20)
        rst.high()
        sleep(ms: 120)
        
        wakeUp()
        sleep(ms: 120)
    }
    
    public func setAddrWindow(x: Int, y: Int, width w: Int, height h: Int) {
        let xStartHigh = UInt8( (x + xOffset) >> 8 )
        let xStartLow  = UInt8( (x + xOffset) & 0xFF )
        let xEndHigh = UInt8( (x + w + xOffset - 1) >> 8 )
        let xEndLow = UInt8( (x + w + xOffset - 1) & 0xFF )
        
        let yStartHigh = UInt8( (y + yOffset) >> 8 )
        let yStartLow  = UInt8( (y + yOffset) & 0xFF )
        let yEndHigh = UInt8( (y + h + yOffset - 1) >> 8 )
        let yEndLow = UInt8( (y + h + yOffset - 1) & 0xFF )
        
        writeConfig([xStartHigh, xStartLow, xEndHigh, xEndLow], to: .CASET)
        writeConfig([yStartHigh, yStartLow, yEndHigh, yEndLow], to: .RASET)
        writeCommand(.RAMWR)
    }
}

extension ST7796 {
    enum Command: UInt8 {
        case NOP        = 0x00
        case SWRESET    = 0x01
        case RDDID      = 0x04
        case RDDST      = 0x09
        
        case SLPIN      = 0x10
        case SLPOUT     = 0x11
        case PTLON      = 0x12
        case NORON      = 0x13
        
        case INVOFF     = 0x20
        case INVON      = 0x21
        case DISPOFF    = 0x28
        case DISPON     = 0x29
        case CASET      = 0x2A
        case RASET      = 0x2B
        case RAMWR      = 0x2C
        case RAMRD      = 0x2E
        
        case PTLAR      = 0x30
        case TEOFF      = 0x34
        case TEON       = 0x35
        case MADCTL     = 0x36
        case COLMOD     = 0x3A
        
        case IFMODE     = 0xB0
        case FRMCTR1    = 0xB1
        case FRMCTR2    = 0xB2
        case FRMCTR3    = 0xB3
        case DIC        = 0xB4
        case BPC        = 0xB5
        case DFC        = 0xB6
        case EM         = 0xB7
        
        case PWR1       = 0xC0
        case PWR2       = 0xC1
        case PWR3       = 0xC2
        case VCMPCTL    = 0xC5
        case VCMOFFSET  = 0xC6
        
        case NVMADW     = 0xD0
        case NVMBPROG   = 0xD1
        case NVMSTATUS  = 0xD2
        case RDID4      = 0xD3
        
        case PGC        = 0xE0
        case NGC        = 0xE1
        case DGC1       = 0xE2
        case DGC2       = 0xE3
        case DOCA       = 0xE8

        case CSCON      = 0xF0
        case SPIREADCTL = 0xFB
    }
    
    struct MadctlConfig: OptionSet {
        let rawValue: UInt8
        
        static let pageTopToBottom = MadctlConfig([])
        static let pageBottomToTop = MadctlConfig(rawValue: 0x80)
        
        static let leftToRight = MadctlConfig([])
        static let rightToLeft = MadctlConfig(rawValue: 0x40)
        
        static let normalMode = MadctlConfig([])
        static let reverseMode = MadctlConfig(rawValue: 0x20)
        
        static let lineTopToBottom = MadctlConfig([])
        static let lineBottomToTop = MadctlConfig(rawValue: 0x10)
        
        static let RGB = MadctlConfig([])
        static let BGR = MadctlConfig(rawValue: 0x08)
    }
    
    
    func wakeUp() {
        writeCommand(.SLPOUT)
    }
    
    func writeConfig(_ data: [UInt8]?, to address: Command) {
        writeCommand(address)
        if let data = data {
            writeData(data)
        }
    }
    
    func writeCommand(_ command: Command) {
        dc.low()
        cs.low()
        spi.write(command.rawValue)
        cs.high()
        dc.high()
    }
    
    func writeData(_ data: [UInt8]) {
        cs.low()
        spi.write(data)
        cs.high()
    }

    func writeData(_ data: [UInt16], count: Int) {
        cs.low()
        spi.write(data, count: count)
        cs.high()
    }

    func writeData(_ data: UnsafeRawBufferPointer, count: Int) {
        cs.low()
        spi.write(data, count: count)
        cs.high()
    }
}