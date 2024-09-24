//=== ST7789.swift --------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Andy Liu
// Created: 04/22/2021
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO


/// This is the library for ST7789 SPI screen.
/// It supports two sizes of screens: 240x240 and 240x320.
///
/// It has 16-bit color pixels. One pixel matches one point of the
/// coordinate system on the screen. It starts from (0,0).
/// The origin of the display is on the top left corner by default.
/// x and y coordinates go up respectively to the right and downwards.
/// The origin can also be changed to any of the four corners of the screen
/// as you rotate the display.
public final class ST7789 {
    
    
    /// The rotation angles of the screen.
    public enum Rotation {
        case angle0, angle90, angle180, angle270
    }
    
    private let initConfigs: [(address: Command, data: [UInt8]?)] = [
        (.COLMOD, [0x55]),
        (.INVON, nil),
        (.DISPON, nil)
    ]

    /*
     private let initConfigs: [(address: Command, data: [UInt8]?)] = [
     (.COLMOD, [0x05]),

     (.PORCTRL, [0x0C, 0x0C, 0x00, 0x33, 0x33]),
     (.GCTRL, [0x35]),
     (.VCOMS, [0x19]),
     (.LCMCTRL, [0x2C]),
     (.VDVVRHEN, [0x01]),
     (.VRHS, [0x12]),
     (.VDVSET, [0x20]),
     (.FRCTR2, [0x0F]),
     (.PWCTRL1, [0xA4, 0xA1]),
     (.PVGAMCTRL, [0xD0, 0x04, 0x0A, 0x08, 0x07, 0x05, 0x32,
     0x32, 0x48, 0x38, 0x15, 0x15, 0x2A, 0x2E]),
     (.NVGAMCTRL, [0xD0, 0x07, 0x0D, 0x09, 0x09, 0x16, 0x30,
     0x44, 0x49, 0x39, 0x16, 0x16, 0x2B, 0x2F]),

     (.INVON, nil),
     (.DISPON, nil)
     ]
     */
    
    let spi: SPI
    let cs, dc, rst, bl: DigitalOut
    
    private(set) var rotation: Rotation
    
    public private(set) var width: Int
    public private(set) var height: Int
    
    private var xOffset: Int
    private var yOffset: Int

    
    /// Initialize all the necessary pins and set the parameters of the screen.
    /// The ST7789 chip can drive 240x240 and 240x320 screens.
    /// 240x240 by default.
    /// - Parameters:
    ///   - spi: **REQUIRED** SPI interface. The communication speed between
    ///     two devices should be as fast as possible within the range,
    ///     usually 30,000,000.
    ///   - cs: **REQUIRED** The digital output pin used for chip select.
    ///   - dc: **REQUIRED** The digital output pin used for data or command.
    ///   - rst: **REQUIRED** The digital output pin used to reset the screen.
    ///   - bl: **REQUIRED** The digital output pin used for backlight control.
    ///   - width: **OPTIONAL** The width of the screen. It is 240 by default.
    ///   - height: **OPTIONAL** The height of the screen. It is 240 by default.
    ///   - rotation: **OPTIONAL** Set the origin and rotation of the screen.
    ///     By default, the origin is on top left of the screen.
    public init(spi: SPI, cs: DigitalOut, dc: DigitalOut,
                rst: DigitalOut, bl: DigitalOut,
                width: Int = 240, height: Int = 240,
                rotation: Rotation = .angle0) {
        guard (width == 240 && height == 240)
                || (width == 240 && height == 320)
                || (width == 320 && height == 240)
                || (width == 135 && height == 240)
                || (width == 240 && height == 135)
                || (width == 172 && height == 320)
                || (width == 320 && height == 172)
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
            case (240, 240):
                switch rotation {
                case .angle0:
                    xOffset = 0
                    yOffset = 0
                    madctlConfig = [.pageTopToBottom, .leftToRight,
                                    .normalMode, .lineTopToBottom, .RGB]
                case .angle90:
                    xOffset = 0
                    yOffset = 0
                    madctlConfig = [.pageTopToBottom, .rightToLeft,
                                    .reverseMode, .lineTopToBottom, .RGB]
                case .angle180:
                    xOffset = 0
                    yOffset = 80
                    madctlConfig = [.pageBottomToTop, .rightToLeft,
                                    .normalMode, .lineTopToBottom, .RGB]
                case .angle270:
                    xOffset = 80
                    yOffset = 0
                    madctlConfig = [.pageBottomToTop, .leftToRight,
                                    .reverseMode, .lineTopToBottom, .RGB]
                }
            case (240, 320):
                xOffset = 0
                yOffset = 0
                switch rotation {
                case .angle0:
                    madctlConfig = [.pageTopToBottom, .leftToRight,
                                    .normalMode, .lineTopToBottom, .RGB]
                case .angle90:
                    swap(&width, &height)
                    madctlConfig = [.pageTopToBottom, .rightToLeft,
                                    .reverseMode, .lineTopToBottom, .RGB]
                case .angle180:
                    madctlConfig = [.pageBottomToTop, .rightToLeft,
                                    .normalMode, .lineTopToBottom, .RGB]
                case .angle270:
                    swap(&width, &height)
                    madctlConfig = [.pageBottomToTop, .leftToRight,
                                    .reverseMode, .lineTopToBottom, .RGB]
                }
            case (320, 240):
                xOffset = 0
                yOffset = 0
                switch rotation {
                case .angle0:
                    madctlConfig = [.pageTopToBottom, .rightToLeft,
                                    .reverseMode, .lineTopToBottom, .RGB]
                case .angle90:
                    swap(&width, &height)
                    madctlConfig = [.pageBottomToTop, .rightToLeft,
                                    .normalMode, .lineTopToBottom, .RGB]
                case .angle180:
                    madctlConfig = [.pageBottomToTop, .leftToRight,
                                    .reverseMode, .lineTopToBottom, .RGB]
                case .angle270:
                    swap(&width, &height)
                    madctlConfig = [.pageTopToBottom, .leftToRight,
                                    .normalMode, .lineTopToBottom, .RGB]
                }
            case (135, 240):
                switch rotation {
                case .angle0:
                    xOffset = 52
                    yOffset = 40
                    madctlConfig = [.pageTopToBottom, .leftToRight,
                                    .normalMode, .lineTopToBottom, .RGB]
                case .angle90:
                    xOffset = 40
                    yOffset = 53
                    swap(&width, &height)
                    madctlConfig = [.pageTopToBottom, .rightToLeft,
                                    .reverseMode, .lineBottomToTop, .RGB]
                case .angle180:
                    xOffset = 53
                    yOffset = 40
                    madctlConfig = [.pageBottomToTop, .rightToLeft,
                                    .normalMode, .lineTopToBottom, .RGB]
                case .angle270:
                    xOffset = 40
                    yOffset = 52
                    swap(&width, &height)
                    madctlConfig = [.pageBottomToTop, .leftToRight,
                                    .reverseMode, .lineTopToBottom, .RGB]
                }
            case (240, 135):
                switch rotation {
                case .angle0:
                    xOffset = 40
                    yOffset = 53
                    madctlConfig = [.pageTopToBottom, .rightToLeft,
                                    .reverseMode, .lineBottomToTop, .RGB]
                case .angle90:
                    xOffset = 53
                    yOffset = 40
                    swap(&width, &height)
                    madctlConfig = [.pageBottomToTop, .rightToLeft,
                                    .normalMode, .lineTopToBottom, .RGB]
                case .angle180:
                    xOffset = 40
                    yOffset = 52
                    madctlConfig = [.pageBottomToTop, .leftToRight,
                                    .reverseMode, .lineTopToBottom, .RGB]
                case .angle270:
                    xOffset = 52
                    yOffset = 40
                    swap(&width, &height)
                    madctlConfig = [.pageTopToBottom, .leftToRight,
                                    .normalMode, .lineTopToBottom, .RGB]
                }
            case (172, 320):
                switch rotation {
                case .angle0:
                    xOffset = 34
                    yOffset = 0
                    madctlConfig = [.pageTopToBottom, .leftToRight,
                                    .normalMode, .lineTopToBottom, .RGB]
                case .angle90:
                    xOffset = 0
                    yOffset = 34
                    swap(&width, &height)
                    madctlConfig = [.pageTopToBottom, .rightToLeft,
                                    .reverseMode, .lineBottomToTop, .RGB]
                case .angle180:
                    xOffset = 34
                    yOffset = 0
                    madctlConfig = [.pageBottomToTop, .rightToLeft,
                                    .normalMode, .lineTopToBottom, .RGB]
                case .angle270:
                    xOffset = 0
                    yOffset = 34
                    swap(&width, &height)
                    madctlConfig = [.pageBottomToTop, .leftToRight,
                                    .reverseMode, .lineTopToBottom, .RGB]
                }
            case (320, 172):
                switch rotation {
                case .angle0:
                    xOffset = 0
                    yOffset = 34
                    madctlConfig = [.pageTopToBottom, .rightToLeft,
                                    .reverseMode, .lineBottomToTop, .RGB]
                case .angle90:
                    xOffset = 34
                    yOffset = 0
                    swap(&width, &height)
                    madctlConfig = [.pageBottomToTop, .rightToLeft,
                                    .normalMode, .lineTopToBottom, .RGB]
                case .angle180:
                    xOffset = 0
                    yOffset = 34
                    madctlConfig = [.pageBottomToTop, .leftToRight,
                                    .reverseMode, .lineTopToBottom, .RGB]
                case .angle270:
                    xOffset = 34
                    yOffset = 0
                    swap(&width, &height)
                    madctlConfig = [.pageTopToBottom, .leftToRight,
                                    .normalMode, .lineTopToBottom, .RGB]
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

extension ST7789 {
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
        
        case RAMCTRL    = 0xB0
        case RGBCTRL    = 0xB1
        case PORCTRL    = 0xB2
        case FRCTRL1    = 0xB3
        case PARCTRL    = 0xB5
        case GCTRL      = 0xB7
        case GTADJ      = 0xB8
        case DGMEN      = 0xBA
        case VCOMS      = 0xBB
        case POWSAVE    = 0xBC
        case DLPOFFSAVE = 0xBD
        
        case LCMCTRL    = 0xC0
        case IDSET      = 0xC1
        case VDVVRHEN   = 0xC2
        case VRHS       = 0xC3
        case VDVSET     = 0xC4
        case VCMOFSET   = 0xC5
        case FRCTR2     = 0xC6
        case CABCCTRL   = 0xC7
        case REGSEL1    = 0xC8
        case REGSEL2    = 0xCA
        case PWMFRSEL   = 0xCC
        
        case PWCTRL1    = 0xD0
        case VAPVANEN   = 0xD2
        case CMD2EN     = 0xDF
        
        case PVGAMCTRL  = 0xE0
        case NVGAMCTRL  = 0xE1
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