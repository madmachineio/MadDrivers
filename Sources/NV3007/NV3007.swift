//=== NV3007.swift --------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Andy Liu
// Created: 01/26/2026
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO


/// This is the library for NV3007 SPI screen.
/// It supports the size of screen: 142x428.
///
/// It has 16-bit color pixels. One pixel matches one point of the
/// coordinate system on the screen. It starts from (0,0).
/// The origin of the display is on the top left corner by default.
/// x and y coordinates go up respectively to the right and downwards.
/// The origin can also be changed to any of the four corners of the screen
/// as you rotate the display.
public final class NV3007 {

    /// The rotation angles of the screen.
    public enum Rotation {
        case angle0, angle90, angle180, angle270
    }

    private let initConfigs: [(address: Command, data: [UInt8]?)] = [
        (.CMD_FF, [0xA5]),
        (.PWRCTRL12, [0x08]),
        (.PWRCTRL13, [0x08]),
        (.PWRCTRL14, [0xB0]),
        (.PWRCTRL15, [0x16]),
        (.PWRCTRL16, [0xC4]),
        (.PWRCTRL1, [0x55, 0x04]),
        (.GLDOCTRL2, [0x90]),
        (.GLDOCTRL1, [0x7B]),
        (.GLDOCTRL3, [0x33]),

        (.GAMCTRL1, [0x00]),
        (.GAMCTRL17, [0x00]),
        (.GAMCTRL2, [0x02]),
        (.GAMCTRL18, [0x02]),
        (.GAMCTRL3, [0x04]),
        (.GAMCTRL19, [0x04]),
        (.GAMCTRL13, [0x29]),
        (.GAMCTRL29, [0x29]),
        (.GAMCTRL14, [0x31]),
        (.GAMCTRL30, [0x31]),
        (.GAMCTRL15, [0x0F]),
        (.GAMCTRL31, [0x0F]),
        (.GAMCTRL7, [0x21]),
        (.GAMCTRL23, [0x21]),
        (.GAMCTRL9, [0x3A]),
        (.GAMCTRL25, [0x3A]),
        (.GAMCTRL4, [0x07]),
        (.GAMCTRL20, [0x07]),
        (.GAMCTRL5, [0x05]),
        (.GAMCTRL21, [0x05]),
        (.GAMCTRL6, [0x02]),
        (.GAMCTRL22, [0x02]),
        (.GAMCTRL8, [0x23]),
        (.GAMCTRL24, [0x23]),
        (.GAMCTRL10, [0x08]),
        (.GAMCTRL26, [0x08]),
        (.GAMCTRL11, [0x13]),
        (.GAMCTRL27, [0x13]),
        (.GAMCTRL12, [0x13]),
        (.GAMCTRL28, [0x13]),
        (.GAMCTRL16, [0x00]),
        (.GAMCTRL32, [0x00]),

        (.CMD_50, [0x00]),
        (.CMD_52, [0xD6]),
        (.ITCTRL1, [0x08]),
        (.ITCTRL2, [0x08]),
        (.ITCTRL3, [0x1E]),
        (.ITCTRL4, [0x1C]),

        // GOA map_sel
        (.GOACTRL, [0x2B, 0x24, 0x00]),
        (.VSTCTRL1, [0x87]),
        (.VSTCTRL2, [0x86]),
        (.VSTCTRL5, [0x00]),
        (.VSTCTRL6, [0x00]),
        (.VSTCTRL7, [0x00]),
        (.VSTCTRL8, [0x36]),
        (.VSTCTRL9, [0x7E]),
        (.VSTCTRL10, [0x7E]),

        (.CLKCTRL1, [0x85]),
        (.CLKCTRL2, [0x84]),
        (.CLKCTRL3, [0x83]),
        (.CLKCTRL4, [0x82]),
        (.CLKCTRL5, [0x81]),
        (.CLKCTRL6, [0x80]),
        (.CLKCTRL7, [0x01]),
        (.CLKCTRL8, [0x02]),
        (.CLKCTRL9, [0x00]),
        (.CLKCTRL10, [0x00]),
        (.CLKCTRL11, [0x00]),
        (.CLKCTRL12, [0x33]),
        (.CLKCTRL13, [0x7E]),
        (.CLKCTRL14, [0x7E]),
        (.CLKCTRL16, [0x33, 0x33]),
        (.CLKCTRL17, [0x68]),
        (.CLKCTRL18, [0x69]),
        (.CLKCTRL19, [0x6A]),
        (.CLKCTRL20, [0x6B]),
        (.CLKCTRL21, [0x33, 0x33]),
        (.CLKCTRL22, [0x6C]),
        (.CLKCTRL23, [0x6D]),
        (.CLKCTRL24, [0x6E]),
        (.CLKCTRL25, [0x6F]),

        (.VENDCTRL1, [0x03, 0x67]),
        (.VENDCTRL2, [0x03, 0x6B]),
        (.VENDCTRL3, [0x03, 0x68]),
        (.VENDCTRL4, [0x03, 0x6C]),

        (.VENDCTRL9, [0x00]),
        (.VENDCTRL10, [0x00]),
        (.VENDCTRL11, [0x00]),
        (.VENDCTRL12, [0x32]),
        (.VENDCTRL13, [0x7E]),
        (.VENDCTRL14, [0x7E]),

        (.SOUCTRL1, [0x00]),
        (.SOUCTRL2, [0x03, 0x0F]),
        (.SOUCTRL3, [0x04]),
        (.SOUCTRL4, [0x01]),
        (.SOUCTRL5, [0x0E]),
        (.SOUCTRL6, [0x01]),
        (.SOUCTRL7, [0x19]),
        (.SOUCTRL8, [0x10]),
        (.SOUCTRL9, [0x10]),
        (.SOUCTRL11, [0x12]),
        (.SOUCTRL12, [0xD0]),
        (.SOUCTRL13, [0x04]),
        (.SOUCTRL14, [0x07]),
        (.SOUCTRL15, [0x07]),
        (.SOUCTRL16, [0x09]),
        (.SOUCTRL17, [0xD0]),
        (.SOUCTRL18, [0x0E]),

        (.FSMCTRL, [0x17]),
        (.SOUCTRL19, [0x2C, 0x1B, 0x0B, 0x20]),

        // 1 dot
        (.SOUCTRL10, [0x29]),
        (.SOUCTRL13, [0x04]),

        // TE
        (.TEON, [0x00]),
        (.TECTRL1, [0x00, 0x10]),
        (.TECTRL3, [0x10]),

        (.CMD_FF, [0x00]),
        (.PFSET, [0x05])
    ]

    let spi: SPI
    let cs, dc, rst, bl: DigitalOut

    private(set) var rotation: Rotation

    public private(set) var width: Int
    public private(set) var height: Int

    private var xOffset: Int
    private var yOffset: Int


    /// Initialize all the necessary pins and set the parameters of the screen.
    /// The NV3007 chip can drive 142x428 screen.
    /// - Parameters:
    ///   - spi: **REQUIRED** SPI interface. The communication speed between
    ///     two devices should be as fast as possible within the range,
    ///     usually 30,000,000.
    ///   - cs: **REQUIRED** The digital output pin used for chip select.
    ///   - dc: **REQUIRED** The digital output pin used for data or command.
    ///   - rst: **REQUIRED** The digital output pin used to reset the screen.
    ///   - bl: **REQUIRED** The digital output pin used for backlight control.
    ///   - width: **OPTIONAL** The width of the screen. It is 142 by default.
    ///   - height: **OPTIONAL** The height of the screen. It is 428 by default.
    ///   - rotation: **OPTIONAL** Set the origin and rotation of the screen.
    ///     By default, the origin is on top left of the screen.
    public init(spi: SPI, cs: DigitalOut, dc: DigitalOut,
                rst: DigitalOut, bl: DigitalOut,
                width: Int = 428, height: Int = 142,
                rotation: Rotation = .angle0) {
        guard (width == 428 && height == 142)
                || (width == 142 && height == 428)
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

        wakeUp()
        sleep(ms: 220)
        writeCommand(.DISPON)
        sleep(ms: 200)

        clearScreen()
        bl.high()
    }


    /// Change the orientation of the display and set the origin of the
    /// coordinate system. The rotation angle has four choices, which
    /// correspond to the four corners on the screen.
    /// - Parameter angle: The rotation angle.
    public func setRoation(_ angle: Rotation) {
        rotation = angle
        var madctlValue: UInt8 = 0x00

        let ratio = (width, height)

        switch ratio {
            case (142, 428):
                switch rotation {
                case .angle0:
                    xOffset = 12
                    yOffset = 0
                    madctlValue = 0x00
                case .angle90:
                    xOffset = 0
                    yOffset = 14
                    madctlValue = 0x60
                    swap(&width, &height)
                case .angle180:
                    xOffset = 14
                    yOffset = 0
                    madctlValue = 0xC0
                case .angle270:
                    xOffset = 0
                    yOffset = 12
                    madctlValue = 0xA0
                    swap(&width, &height)
                }
            case (428, 142):
                switch rotation {
                case .angle0:
                    xOffset = 0
                    yOffset = 14
                    madctlValue = 0x60
                case .angle90:
                    xOffset = 14
                    yOffset = 0
                    madctlValue = 0xC0
                    swap(&width, &height)
                case .angle180:
                    xOffset = 0
                    yOffset = 12
                    madctlValue = 0xA0
                case .angle270:
                    xOffset = 12
                    yOffset = 0
                    madctlValue = 0x00
                    swap(&width, &height)
                }
            default:
                break
        }

        writeConfig([madctlValue], to: .MADCTL)
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
        sleep(ms: 50)
        rst.high()
        sleep(ms: 120)
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

extension NV3007 {
    struct Command: RawRepresentable, Equatable {
        let rawValue: UInt8
        init(rawValue: UInt8) { self.rawValue = rawValue }

        static let NOP = Command(rawValue: 0x00)
        static let RDDIDIF = Command(rawValue: 0x04)
        static let RDDST = Command(rawValue: 0x09)
        static let SLPIN = Command(rawValue: 0x10)
        static let SLPOUT = Command(rawValue: 0x11)
        static let PARMON = Command(rawValue: 0x12)
        static let NORMON = Command(rawValue: 0x13)
        static let INVOFF = Command(rawValue: 0x20)
        static let INVON = Command(rawValue: 0x21)
        static let DISPOFF = Command(rawValue: 0x28)
        static let DISPON = Command(rawValue: 0x29)
        static let CASET = Command(rawValue: 0x2A)
        static let RASET = Command(rawValue: 0x2B)
        static let RAMWR = Command(rawValue: 0x2C)
        static let RAMRD = Command(rawValue: 0x2E)
        static let PAREA = Command(rawValue: 0x30)
        static let VSDEF = Command(rawValue: 0x33)
        static let TEOFF = Command(rawValue: 0x34)
        static let TEON = Command(rawValue: 0x35)
        static let MADCTL = Command(rawValue: 0x36)
        static let VSSAD = Command(rawValue: 0x37)
        static let IDLEOFF = Command(rawValue: 0x38)
        static let IDLEON = Command(rawValue: 0x39)
        static let PFSET = Command(rawValue: 0x3A)
        static let WRMEMC = Command(rawValue: 0x3C)
        static let HSDEF = Command(rawValue: 0x3D)
        static let HSSAD = Command(rawValue: 0x3E)

        static let IFCTRL1 = Command(rawValue: 0x40)
        static let IFCTRL2 = Command(rawValue: 0x41)
        static let IFCTRL3 = Command(rawValue: 0x42)
        static let IFCTRL4 = Command(rawValue: 0x43)
        static let TECTRL1 = Command(rawValue: 0x44)
        static let TECTRL2 = Command(rawValue: 0x45)
        static let TECTRL3 = Command(rawValue: 0x46)
        static let TECTRL4 = Command(rawValue: 0x47)
        static let TECTRL5 = Command(rawValue: 0x48)
        static let SCANCTRL = Command(rawValue: 0x49)
        static let OPTCTRL1 = Command(rawValue: 0x4A)
        static let OPTCTRL2 = Command(rawValue: 0x4B)
        static let OPTCTRL3 = Command(rawValue: 0x4C)
        static let OPTCTRL4 = Command(rawValue: 0x4D)
        static let USRMAD = Command(rawValue: 0x4F)

        static let CMD_50 = Command(rawValue: 0x50)
        static let CMD_52 = Command(rawValue: 0x52)
        static let ITCTRL1 = Command(rawValue: 0x53)
        static let ITCTRL2 = Command(rawValue: 0x54)
        static let ITCTRL3 = Command(rawValue: 0x55)
        static let ITCTRL4 = Command(rawValue: 0x56)
        static let BIASCTRL = Command(rawValue: 0x57)
        static let LVDCTRL = Command(rawValue: 0x59)
        static let RAMCTRL1 = Command(rawValue: 0x5C)
        static let RAMCTRL2 = Command(rawValue: 0x5D)
        static let RDBIST = Command(rawValue: 0x5E)

        static let GAMCTRL1 = Command(rawValue: 0x60)
        static let GAMCTRL2 = Command(rawValue: 0x61)
        static let GAMCTRL3 = Command(rawValue: 0x62)
        static let GAMCTRL4 = Command(rawValue: 0x63)
        static let GAMCTRL5 = Command(rawValue: 0x64)
        static let GAMCTRL6 = Command(rawValue: 0x65)
        static let GAMCTRL7 = Command(rawValue: 0x66)
        static let GAMCTRL8 = Command(rawValue: 0x67)
        static let GAMCTRL9 = Command(rawValue: 0x68)
        static let GAMCTRL10 = Command(rawValue: 0x69)
        static let GAMCTRL11 = Command(rawValue: 0x6A)
        static let GAMCTRL12 = Command(rawValue: 0x6B)
        static let GAMCTRL13 = Command(rawValue: 0x6C)
        static let GAMCTRL14 = Command(rawValue: 0x6D)
        static let GAMCTRL15 = Command(rawValue: 0x6E)
        static let GAMCTRL16 = Command(rawValue: 0x6F)
        static let GAMCTRL17 = Command(rawValue: 0x70)
        static let GAMCTRL18 = Command(rawValue: 0x71)
        static let GAMCTRL19 = Command(rawValue: 0x72)
        static let GAMCTRL20 = Command(rawValue: 0x73)
        static let GAMCTRL21 = Command(rawValue: 0x74)
        static let GAMCTRL22 = Command(rawValue: 0x75)
        static let GAMCTRL23 = Command(rawValue: 0x76)
        static let GAMCTRL24 = Command(rawValue: 0x77)
        static let GAMCTRL25 = Command(rawValue: 0x78)
        static let GAMCTRL26 = Command(rawValue: 0x79)
        static let GAMCTRL27 = Command(rawValue: 0x7A)
        static let GAMCTRL28 = Command(rawValue: 0x7B)
        static let GAMCTRL29 = Command(rawValue: 0x7C)
        static let GAMCTRL30 = Command(rawValue: 0x7D)
        static let GAMCTRL31 = Command(rawValue: 0x7E)
        static let GAMCTRL32 = Command(rawValue: 0x7F)

        static let RGLRCTRL1 = Command(rawValue: 0x80)
        static let RGLRCTRL2 = Command(rawValue: 0x81)
        static let VDDSCTRL = Command(rawValue: 0x82)
        static let GLDOCTRL1 = Command(rawValue: 0x83)
        static let GLDOCTRL2 = Command(rawValue: 0x84)
        static let GLDOCTRL3 = Command(rawValue: 0x85)
        static let ESDCTRL2 = Command(rawValue: 0x8B)
        static let ESDCTRL3 = Command(rawValue: 0x8C)
        static let GLDOCTRL4 = Command(rawValue: 0x8D)
        static let RDOTPDL = Command(rawValue: 0x8E)

        static let PWRCTRL1 = Command(rawValue: 0x8F)
        static let PWRCTRL2 = Command(rawValue: 0x90)
        static let PWRCTRL3 = Command(rawValue: 0x91)
        static let PWRCTRL4 = Command(rawValue: 0x92)
        static let PWRCTRL5 = Command(rawValue: 0x93)
        static let PWRCTRL6 = Command(rawValue: 0x94)
        static let PWRCTRL7 = Command(rawValue: 0x95)
        static let PWRCTRL8 = Command(rawValue: 0x96)
        static let PWRCTRL9 = Command(rawValue: 0x97)
        static let PWRCTRL10 = Command(rawValue: 0x98)
        static let PWRCTRL11 = Command(rawValue: 0x99)
        static let PWRCTRL12 = Command(rawValue: 0x9A)
        static let PWRCTRL13 = Command(rawValue: 0x9B)
        static let PWRCTRL14 = Command(rawValue: 0x9C)
        static let PWRCTRL15 = Command(rawValue: 0x9D)
        static let PWRCTRL16 = Command(rawValue: 0x9E)
        static let PWRCTRL17 = Command(rawValue: 0x9F)

        static let GOACTRL = Command(rawValue: 0xA0)
        static let VSTCTRL1 = Command(rawValue: 0xA1)
        static let VSTCTRL2 = Command(rawValue: 0xA2)
        static let VSTCTRL3 = Command(rawValue: 0xA3)
        static let VSTCTRL4 = Command(rawValue: 0xA4)
        static let VSTCTRL5 = Command(rawValue: 0xA5)
        static let VSTCTRL6 = Command(rawValue: 0xA6)
        static let VSTCTRL7 = Command(rawValue: 0xA7)
        static let VSTCTRL8 = Command(rawValue: 0xA8)
        static let VSTCTRL9 = Command(rawValue: 0xA9)
        static let VSTCTRL10 = Command(rawValue: 0xAA)

        static let VENDCTRL1 = Command(rawValue: 0xAB)
        static let VENDCTRL2 = Command(rawValue: 0xAC)
        static let VENDCTRL3 = Command(rawValue: 0xAD)
        static let VENDCTRL4 = Command(rawValue: 0xAE)
        static let VENDCTRL5 = Command(rawValue: 0xAF)
        static let VENDCTRL6 = Command(rawValue: 0xB0)
        static let VENDCTRL9 = Command(rawValue: 0xB3)
        static let VENDCTRL10 = Command(rawValue: 0xB4)
        static let VENDCTRL11 = Command(rawValue: 0xB5)
        static let VENDCTRL12 = Command(rawValue: 0xB6)
        static let VENDCTRL13 = Command(rawValue: 0xB7)
        static let VENDCTRL14 = Command(rawValue: 0xB8)

        static let CLKCTRL1 = Command(rawValue: 0xB9)
        static let CLKCTRL2 = Command(rawValue: 0xBA)
        static let CLKCTRL3 = Command(rawValue: 0xBB)
        static let CLKCTRL4 = Command(rawValue: 0xBC)
        static let CLKCTRL5 = Command(rawValue: 0xBD)
        static let CLKCTRL6 = Command(rawValue: 0xBE)
        static let CLKCTRL7 = Command(rawValue: 0xBF)
        static let CLKCTRL8 = Command(rawValue: 0xC0)
        static let CLKCTRL9 = Command(rawValue: 0xC1)
        static let CLKCTRL10 = Command(rawValue: 0xC2)
        static let CLKCTRL11 = Command(rawValue: 0xC3)
        static let CLKCTRL12 = Command(rawValue: 0xC4)
        static let CLKCTRL13 = Command(rawValue: 0xC5)
        static let CLKCTRL14 = Command(rawValue: 0xC6)
        static let CLKCTRL15 = Command(rawValue: 0xC7)
        static let CLKCTRL16 = Command(rawValue: 0xC8)
        static let CLKCTRL17 = Command(rawValue: 0xC9)
        static let CLKCTRL18 = Command(rawValue: 0xCA)
        static let CLKCTRL19 = Command(rawValue: 0xCB)
        static let CLKCTRL20 = Command(rawValue: 0xCC)
        static let CLKCTRL21 = Command(rawValue: 0xCD)
        static let CLKCTRL22 = Command(rawValue: 0xCE)
        static let CLKCTRL23 = Command(rawValue: 0xCF)
        static let CLKCTRL24 = Command(rawValue: 0xD0)
        static let CLKCTRL25 = Command(rawValue: 0xD1)

        static let RSTCTRL1 = Command(rawValue: 0xD2)
        static let RSTCTRL2 = Command(rawValue: 0xD3)
        static let RSTCTRL3 = Command(rawValue: 0xD4)
        static let RSTCTRL4 = Command(rawValue: 0xD5)
        static let RSTCTRL5 = Command(rawValue: 0xD6)
        static let RSTCTRL6 = Command(rawValue: 0xD7)
        static let RSTCTRL7 = Command(rawValue: 0xD8)
        static let RSTCTRL8 = Command(rawValue: 0xD9)

        static let RDID1 = Command(rawValue: 0xDA)
        static let RDID2 = Command(rawValue: 0xDB)
        static let RDID3 = Command(rawValue: 0xDC)
        static let WRID1 = Command(rawValue: 0xDD)
        static let WRID2 = Command(rawValue: 0xDE)
        static let WRID3 = Command(rawValue: 0xDF)

        static let SOUCTRL1 = Command(rawValue: 0xE0)
        static let SOUCTRL2 = Command(rawValue: 0xE1)
        static let SOUCTRL3 = Command(rawValue: 0xE2)
        static let SOUCTRL4 = Command(rawValue: 0xE3)
        static let SOUCTRL5 = Command(rawValue: 0xE4)
        static let SOUCTRL6 = Command(rawValue: 0xE5)
        static let SOUCTRL7 = Command(rawValue: 0xE6)
        static let SOUCTRL8 = Command(rawValue: 0xE7)
        static let SOUCTRL9 = Command(rawValue: 0xE8)
        static let SOUCTRL10 = Command(rawValue: 0xE9)
        static let SOUCTRL11 = Command(rawValue: 0xEA)
        static let SOUCTRL12 = Command(rawValue: 0xEB)
        static let SOUCTRL13 = Command(rawValue: 0xEC)
        static let SOUCTRL14 = Command(rawValue: 0xED)
        static let SOUCTRL15 = Command(rawValue: 0xEE)
        static let SOUCTRL16 = Command(rawValue: 0xEF)
        static let SOUCTRL17 = Command(rawValue: 0xF0)
        static let SOUCTRL18 = Command(rawValue: 0xF1)
        static let SOUCTRL19 = Command(rawValue: 0xF2)

        static let CPTEST1 = Command(rawValue: 0xF4)
        static let CPTEST2 = Command(rawValue: 0xF5)
        static let FSMCTRL = Command(rawValue: 0xF9)
        static let PADCTRL = Command(rawValue: 0xFB)
        static let RDSTATE = Command(rawValue: 0xFC)
        static let RDPWRSTATUS = Command(rawValue: 0xFD)

        static let CMD_FF = Command(rawValue: 0xFF)

        static let MADCTRL = MADCTL
        static let COLSET = CASET
        static let ROWSET = RASET
        static let MEMWR = RAMWR
        static let MEMRD = RAMRD
        static let COLMOD = PFSET
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
