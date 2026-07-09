//=== AXS15231B.swift ----------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Andy Liu
// Created: 01/31/2026
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO


/// This is the library for AXS15231B SPI screen.
/// It has 16-bit color pixels. One pixel matches one point of the
/// coordinate system on the screen. It starts from (0,0).
/// The origin of the display is on the top left corner by default.
/// x and y coordinates go up respectively to the right and downwards.
/// The origin can also be changed to any of the four corners of the screen
/// as you rotate the display.
public final class AXS15231B {

    /// The rotation angles of the screen.
    public enum Rotation {
        case angle0, angle90, angle180, angle270
    }

    private let initConfigs: [(address: Command, data: [UInt8]?)] = [
        // Based on Espressif's AXS15231B init sequence (known-good).
        (.CMD_BB, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5A, 0xA5]),

        (.CMD_A0, [0x00, 0x10, 0x00, 0x02, 0x00, 0x00, 0x64, 0x3F, 0x20,
                  0x05, 0x3F, 0x3F, 0x00, 0x00, 0x00, 0x00, 0x00]),

        (.CMD_A2, [0x30, 0x04, 0x0A, 0x3C, 0xEC, 0x54, 0xC4, 0x30, 0xAC,
                  0x28, 0x7F, 0x7F, 0x7F, 0x20, 0xF8, 0x10, 0x02, 0xFF,
                  0xFF, 0xF0, 0x90, 0x01, 0x32, 0xA0, 0x91, 0xC0, 0x20,
                  0x7F, 0xFF, 0x00, 0x54]),

        (.CMD_D0, [0x30, 0xAC, 0x21, 0x24, 0x08, 0x09, 0x10, 0x01, 0xAA,
                  0x14, 0xC2, 0x00, 0x22, 0x22, 0xAA, 0x03, 0x10, 0x12,
                  0x40, 0x14, 0x1E, 0x51, 0x15, 0x00, 0x40, 0x10, 0x00,
                  0x03, 0x3D, 0x12]),

        (.CMD_A3, [0xA0, 0x06, 0xAA, 0x08, 0x08, 0x02, 0x0A, 0x04, 0x04,
                  0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
                  0x04, 0x00, 0x55, 0x55]),

        (.CMD_C1, [0x33, 0x04, 0x02, 0x02, 0x71, 0x05, 0x24, 0x55, 0x02,
                  0x00, 0x41, 0x00, 0x53, 0xFF, 0xFF, 0xFF, 0x4F, 0x52,
                  0x00, 0x4F, 0x52, 0x00, 0x45, 0x3B, 0x0B, 0x02, 0x0D,
                  0x00, 0xFF, 0x40]),

        (.CMD_C3, [0x00, 0x00, 0x00, 0x50, 0x03, 0x00, 0x00, 0x00, 0x01,
                  0x80, 0x01]),

        (.CMD_C4, [0x00, 0x24, 0x33, 0x90, 0x50, 0xEA, 0x64, 0x32, 0xC8,
                  0x64, 0xC8, 0x32, 0x90, 0x90, 0x11, 0x06, 0xDC, 0xFA,
                  0x04, 0x03, 0x80, 0xFE, 0x10, 0x10, 0x00, 0x0A, 0x0A,
                  0x44, 0x50]),

        (.CMD_C5, [0x18, 0x00, 0x00, 0x03, 0xFE, 0x78, 0x33, 0x20, 0x30,
                  0x10, 0x88, 0xDE, 0x0D, 0x08, 0x0F, 0x0F, 0x01, 0x78,
                  0x33, 0x20, 0x10, 0x10, 0x80]),

        (.CMD_C6, [0x05, 0x0A, 0x05, 0x0A, 0x00, 0xE0, 0x2E, 0x0B, 0x12,
                  0x22, 0x12, 0x22, 0x01, 0x00, 0x00, 0x3F, 0x6A, 0x18,
                  0xC8, 0x22]),

        (.CMD_C7, [0x50, 0x32, 0x28, 0x00, 0xA2, 0x80, 0x8F, 0x00, 0x80,
                  0xFF, 0x07, 0x11, 0x9F, 0x6F, 0xFF, 0x26, 0x0C, 0x0D,
                  0x0E, 0x0F]),

        (.CMD_C9, [0x33, 0x44, 0x44, 0x01]),

        (.CMD_CF, [0x34, 0x1E, 0x88, 0x58, 0x13, 0x18, 0x56, 0x18, 0x1E,
                  0x68, 0xF7, 0x00, 0x65, 0x0C, 0x22, 0xC4, 0x0C, 0x77,
                  0x22, 0x44, 0xAA, 0x55, 0x04, 0x04, 0x12, 0xA0, 0x08]),

        (.CMD_D5, [0x3E, 0x3E, 0x88, 0x00, 0x44, 0x04, 0x78, 0x33, 0x20,
                  0x78, 0x33, 0x20, 0x04, 0x28, 0xD3, 0x47, 0x03, 0x03,
                  0x03, 0x03, 0x86, 0x00, 0x00, 0x00, 0x30, 0x52, 0x3F,
                  0x40, 0x40, 0x96]),

        (.CMD_D6, [0x10, 0x32, 0x54, 0x76, 0x98, 0xBA, 0xDC, 0xFE, 0x95,
                  0x00, 0x01, 0x83, 0x75, 0x36, 0x20, 0x75, 0x36, 0x20,
                  0x3F, 0x03, 0x03, 0x03, 0x10, 0x10, 0x00, 0x04, 0x51,
                  0x20, 0x01, 0x00]),

        (.CMD_D7, [0x0A, 0x08, 0x0E, 0x0C, 0x1E, 0x18, 0x19, 0x1F, 0x00,
                  0x1F, 0x1A, 0x1F, 0x3E, 0x3E, 0x04, 0x00, 0x1F, 0x1F,
                  0x1F]),

        (.CMD_D8, [0x0B, 0x09, 0x0F, 0x0D, 0x1E, 0x18, 0x19, 0x1F, 0x01,
                  0x1F, 0x1A, 0x1F]),

        (.CMD_D9, [0x00, 0x0D, 0x0F, 0x09, 0x0B, 0x1F, 0x18, 0x19, 0x1F,
                  0x01, 0x1E, 0x1A, 0x1F]),

        (.CMD_DD, [0x0C, 0x0E, 0x08, 0x0A, 0x1F, 0x18, 0x19, 0x1F, 0x00,
                  0x1E, 0x1A, 0x1F]),

        (.CMD_DF, [0x44, 0x73, 0x4B, 0x69, 0x00, 0x0A, 0x02, 0x90]),

        (.CMD_E0, [0x19, 0x20, 0x0A, 0x13, 0x0E, 0x09, 0x12, 0x28, 0xD4,
                  0x24, 0x0C, 0x35, 0x13, 0x31, 0x36, 0x2F, 0x03]),

        (.CMD_E1, [0x38, 0x20, 0x09, 0x12, 0x0E, 0x08, 0x12, 0x28, 0xC5,
                  0x24, 0x0C, 0x34, 0x12, 0x31, 0x36, 0x2F, 0x27]),

        (.CMD_E2, [0x19, 0x20, 0x0A, 0x11, 0x09, 0x06, 0x11, 0x25, 0xD4,
                  0x22, 0x0B, 0x33, 0x12, 0x2D, 0x32, 0x2F, 0x03]),

        (.CMD_E3, [0x38, 0x20, 0x0A, 0x11, 0x09, 0x06, 0x11, 0x25, 0xC4,
                  0x21, 0x0A, 0x32, 0x11, 0x2C, 0x32, 0x2F, 0x27]),

        (.CMD_E4, [0x19, 0x20, 0x0D, 0x14, 0x0D, 0x08, 0x12, 0x2A, 0xD4,
                  0x26, 0x0E, 0x35, 0x13, 0x34, 0x39, 0x2F, 0x03]),

        (.CMD_E5, [0x38, 0x20, 0x0D, 0x13, 0x0D, 0x07, 0x12, 0x29, 0xC4,
                  0x25, 0x0D, 0x35, 0x12, 0x33, 0x39, 0x2F, 0x27]),

        (.CMD_BB, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),

        (.NORON, nil),
        (.SLPOUT, nil),
        (.DISPON, nil),
        (.RAMWR, [0x00, 0x00, 0x00, 0x00]),
        (.ALLPOFF, nil)
    ]

    let spi: SPI
    let cs, dc, rst, bl: DigitalOut

    private(set) var rotation: Rotation

    public private(set) var width: Int
    public private(set) var height: Int

    private let baseWidth: Int
    private let baseHeight: Int

    private var xOffset: Int
    private var yOffset: Int


    /// Initialize all the necessary pins and set the parameters of the screen.
    /// - Parameters:
    ///   - spi: **REQUIRED** SPI interface. The communication speed between
    ///     two devices should be as fast as possible within the range,
    ///     usually 30,000,000.
    ///   - cs: **REQUIRED** The digital output pin used for chip select.
    ///   - dc: **REQUIRED** The digital output pin used for data or command.
    ///   - rst: **REQUIRED** The digital output pin used to reset the screen.
    ///   - bl: **REQUIRED** The digital output pin used for backlight control.
    ///   - width: **OPTIONAL** The width of the screen. It is 170 by default.
    ///   - height: **OPTIONAL** The height of the screen. It is 560 by default.
    ///   - rotation: **OPTIONAL** Set the origin and rotation of the screen.
    ///     By default, the origin is on top left of the screen.
    public init(spi: SPI, cs: DigitalOut, dc: DigitalOut,
                rst: DigitalOut, bl: DigitalOut,
                width: Int = 170, height: Int = 560,
                rotation: Rotation = .angle0) {
        guard width > 0 && height > 0 else {
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
        self.baseWidth = width
        self.baseHeight = height
        self.rotation = rotation
        self.xOffset = 0
        self.yOffset = 0

        reset()

        // Follow Espressif's init order: exit sleep, set pixel format, then init cmds.
        writeCommand(.SLPOUT)
        sleep(ms: 100)
        writeConfig([0x55], to: .COLMOD)
        setRoation(rotation)

        for config in initConfigs {
            writeConfig(config.data, to: config.address)
            switch config.address {
            case .SLPOUT, .DISPON, .ALLPOFF:
                sleep(ms: 200)
            default:
                break
            }
        }

        clearScreen()
        bl.high()
    }


    /// Change the orientation of the display and set the origin of the
    /// coordinate system. The rotation angle has four choices, which
    /// correspond to the four corners on the screen.
    /// - Parameter angle: The rotation angle.
    public func setRoation(_ angle: Rotation) {
        rotation = angle
        width = baseWidth
        height = baseHeight
        xOffset = 0
        yOffset = 0

        let ratio = (width, height)
        var madctlConfig: MadctlConfig = [.RGB]

        switch ratio {
            case (170, 560):
                switch rotation {
                case .angle0:
                    madctlConfig = [.topToBottom, .leftToRight,
                                   .normalMode, .RGB]
                case .angle90:
                    swap(&width, &height)
                    madctlConfig = [.topToBottom, .rightToLeft,
                                    .reverseMode, .RGB]
                case .angle180:
                    madctlConfig = [.bottomToTop, .rightToLeft,
                                    .normalMode, .RGB]
                case .angle270:
                    swap(&width, &height)
                    madctlConfig = [.bottomToTop, .leftToRight,
                                    .reverseMode, .RGB]
                }
            case (560, 170):
                switch rotation {
                case .angle0:
                    madctlConfig = [.topToBottom, .leftToRight,
                                    //.reverseMode, .RGB]
                                    .reverseMode, .RGB]
                case .angle90:
                    swap(&width, &height)
                    madctlConfig = [.bottomToTop, .rightToLeft,
                                    .normalMode, .RGB]
                case .angle180:
                    madctlConfig = [.bottomToTop, .leftToRight,
                                    .reverseMode, .RGB]
                case .angle270:
                    swap(&width, &height)
                    madctlConfig = [.topToBottom, .leftToRight,
                                    .normalMode, .RGB]
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
        rst.high()
        sleep(ms: 100)
        rst.low()
        sleep(ms: 200)
        rst.high()
        sleep(ms: 200)
    }

    /// Enter sleep mode.
    public func enterSleep() {
        writeCommand(.DISPOFF)
        sleep(ms: 120)
        writeCommand(.SLPIN)
        sleep(ms: 50)
    }

    /// Exit sleep mode.
    public func exitSleep() {
        writeCommand(.SLPOUT)
        sleep(ms: 120)
        writeCommand(.DISPON)
    }

    public func setAddrWindow(x: Int, y: Int, width w: Int, height h: Int) {
        let xStartHigh = UInt8((x + xOffset) >> 8)
        let xStartLow  = UInt8((x + xOffset) & 0xFF)
        let xEndHigh = UInt8((x + w + xOffset - 1) >> 8)
        let xEndLow = UInt8((x + w + xOffset - 1) & 0xFF)

        let yStartHigh = UInt8((y + yOffset) >> 8)
        let yStartLow  = UInt8((y + yOffset) & 0xFF)
        let yEndHigh = UInt8((y + h + yOffset - 1) >> 8)
        let yEndLow = UInt8((y + h + yOffset - 1) & 0xFF)

        writeConfig([xStartHigh, xStartLow, xEndHigh, xEndLow], to: .CASET)
        writeConfig([yStartHigh, yStartLow, yEndHigh, yEndLow], to: .RASET)
        writeCommand(.RAMWR)
    }
}

extension AXS15231B {
    struct Command: RawRepresentable, Equatable {
        let rawValue: UInt8
        init(rawValue: UInt8) { self.rawValue = rawValue }

        static let NOP      = Command(rawValue: 0x00)
        static let SWRESET  = Command(rawValue: 0x01)

        static let SLPIN    = Command(rawValue: 0x10)
        static let SLPOUT   = Command(rawValue: 0x11)
        static let PTLON    = Command(rawValue: 0x12)
        static let NORON    = Command(rawValue: 0x13)

        static let INVOFF   = Command(rawValue: 0x20)
        static let INVON    = Command(rawValue: 0x21)
        static let ALLPOFF  = Command(rawValue: 0x22)
        static let ALLPON   = Command(rawValue: 0x23)
        static let ALLPFILL = Command(rawValue: 0x24)
        static let GAMSET   = Command(rawValue: 0x26)
        static let DISPOFF  = Command(rawValue: 0x28)
        static let DISPON   = Command(rawValue: 0x29)
        static let CASET    = Command(rawValue: 0x2A)
        static let RASET    = Command(rawValue: 0x2B)
        static let RAMWR    = Command(rawValue: 0x2C)
        static let RAWFILL  = Command(rawValue: 0x2F)

        static let TEOFF    = Command(rawValue: 0x34)
        static let TEON     = Command(rawValue: 0x35)
        static let MADCTL   = Command(rawValue: 0x36)
        static let COLMOD   = Command(rawValue: 0x3A)

        static let CMD_A0 = Command(rawValue: 0xA0)
        static let CMD_A2 = Command(rawValue: 0xA2)
        static let CMD_A3 = Command(rawValue: 0xA3)
        static let CMD_BB = Command(rawValue: 0xBB)

        static let CMD_C1 = Command(rawValue: 0xC1)
        static let CMD_C3 = Command(rawValue: 0xC3)
        static let CMD_C4 = Command(rawValue: 0xC4)
        static let CMD_C5 = Command(rawValue: 0xC5)
        static let CMD_C6 = Command(rawValue: 0xC6)
        static let CMD_C7 = Command(rawValue: 0xC7)
        static let CMD_C9 = Command(rawValue: 0xC9)
        static let CMD_CF = Command(rawValue: 0xCF)

        static let CMD_D0 = Command(rawValue: 0xD0)
        static let CMD_D5 = Command(rawValue: 0xD5)
        static let CMD_D6 = Command(rawValue: 0xD6)
        static let CMD_D7 = Command(rawValue: 0xD7)
        static let CMD_D8 = Command(rawValue: 0xD8)
        static let CMD_D9 = Command(rawValue: 0xD9)
        static let CMD_DD = Command(rawValue: 0xDD)
        static let CMD_DF = Command(rawValue: 0xDF)

        static let CMD_E0 = Command(rawValue: 0xE0)
        static let CMD_E1 = Command(rawValue: 0xE1)
        static let CMD_E2 = Command(rawValue: 0xE2)
        static let CMD_E3 = Command(rawValue: 0xE3)
        static let CMD_E4 = Command(rawValue: 0xE4)
        static let CMD_E5 = Command(rawValue: 0xE5)

        static let CMD_FF = Command(rawValue: 0xFF)
    }

    struct MadctlConfig: OptionSet {
        let rawValue: UInt8
        
        static let topToBottom = MadctlConfig([])
        static let bottomToTop = MadctlConfig(rawValue: 0x80)
        
        static let leftToRight = MadctlConfig([])
        static let rightToLeft = MadctlConfig(rawValue: 0x40)
        
        static let normalMode = MadctlConfig([])
        static let reverseMode = MadctlConfig(rawValue: 0x20)
        
        static let RGB = MadctlConfig([])
        static let BGR = MadctlConfig(rawValue: 0x08)
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
