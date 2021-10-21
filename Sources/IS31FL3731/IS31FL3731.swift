import SwiftIO

#if canImport(MadDisplay)
import struct MadDisplay.ColorSpace
#endif

/**
 This is the library for IS31FL3731 chip. It supports I2C communication. By default, you can use it with a 9x16 LED matrix.
 
 The LED matrix has 16 rows (X0 - X15), each row has 9 LEDs (Y0 - Y8). One LED stands for one pixel. The first LED labeled X0 and Y0 is the origin. There are two ways to indicate it: 0 or (0,0). Each LED has 8-bit grayscale, that is, its brightness has 256 levels. 0 is off and 255 is full brightness.
 
 You can also regard the LED matrix as a 9x16 screen and use `MadDisplay` to display text on it.
 
 - Attention: If you set all pixels to full brightness, the module will require too much current. So you may need to connect an external power supply instead of the computer's USB port. And if you hear buzzing from it, don't worry, it's because it works quickly to switch LED on and off.

 */

public final class IS31FL3731 {

	let i2c: I2C
    let address: UInt8
    /// Width of the LED matrix. It's 16 by default.
    public let width: Int = 16
    /// Height of the LED matrix. It's 9 by default.
    public let height: Int = 9

    public private(set) var currentFrame: UInt8 = 0

    let functionPage: UInt8 = 0x0B

    let configPicutreMode: UInt8   = 0x00
    let configAutoPlayMode: UInt8  = 0x08
    //let configAudioPlayMode: UInt8 = 0x18
    let pwmRegOffset: UInt8 = 0x24

#if canImport(MadDisplay)
    public private(set) var colorSpace = ColorSpace()
#endif

    /**
     Initialize the module to get it ready for lighting.
     - Parameter i2c: **REQUIRED** The I2C interface that the module connects.
     - Parameter address: **OPTIONAL** The address of the module. It has a default value.
     */
    public init(i2c: I2C, address: UInt8 = 0x74) {

        self.i2c = i2c
        self.address = address

#if canImport(MadDisplay)
        colorSpace.depth = 8
        colorSpace.grayscale = true
#endif

        shutdown()
        setToPictureMode()

        for frame in 0..<8 {
            selectPage(UInt8(frame))
            controlRegInit(true)
            blinkRegInit(true)
            fill()
        }
        setToFrame(Int(currentFrame))
        startup()
    }

    public func setToPictureMode(frame: Int? = nil) {
        writeRegister(.configuration, configPicutreMode)
        if let frame = frame {
            setToFrame(frame)
        }
    }
    
    public func setToAutoPlayMode() {
        writeRegister(.configuration, configAutoPlayMode)
    }

    public func setToFrame(_ frame: Int) {
        guard frame < 8 && frame >= 0 else { return }
        currentFrame = UInt8(frame)
        selectPage(currentFrame)
        writeRegister(.pictureDisplay, currentFrame)
    }

    public func startBreath() {
        //writeRegister(.autoPlayDelay, 23)
        writeRegister(.pictureDisplay, currentFrame)
        writeRegister(.breathControl1, 0b0100_0100)
        writeRegister(.breathControl2, 0b0001_0100)
    }

    public func stopBreath() {
        writeRegister(.breathControl2, 0b0000_0100)
    }

    public func setPlayEndFrame(_ frame: Int) {
        var frame = frame
        if frame > 7 || frame < 0 {
            frame = 0
        }
        writeRegister(.autoPlayControl, UInt8(frame))
    }

    /**
     Light an LED by telling its number from 0 to 143. The brightness of the LED can range from 0 (off) to 255 (full brightness).
     
     - Parameter number: **REQUIRED** The location of the LED from 0 to 143.
     - Parameter brightness: **REQUIRED** The brightness of the specified LED. By default, the LED is set to full brightness.
     */
    @inline(__always)
    public func writePixel(_ number: Int, brightness: UInt8 = 255) {
        guard number < width * height && number >= 0 else { return }
        let data = [UInt8(number) + pwmRegOffset, brightness]
        i2c.write(data, to: address)
    }

    /**
     Light an LED by telling its coordinates.
     
     You can know the coordinate from the labels printed on the module.  The x is from 0 to 15 and y is  from 0 to 8. Each LED can have 256 levels of brightness from 0 (off) to 255 (full brightness).
     
     - Parameter x: **REQUIRED** The x coordinate of the LED.
     - Parameter y: **REQUIRED** The y coordinate of the LED.
     - Parameter brightness: **REQUIRED** The brightness of the specified LED. By default, the LED is set to full brightness.
     */
    @inline(__always)
    public func writePixel(x: Int, y: Int, brightness: UInt8 = 255) {
        guard x <= width && y <= height else { return }
        let reg = UInt8(y * width + x) + pwmRegOffset
        let data = [reg, brightness]
        i2c.write(data, to: address)
    }

    /**
     Set a part of the pixels on the matrix by defining the area. The area is a rectangle determined by a starting point, width and height. Then you can set the pixels to any brightness to get a unique lighting effect.
     
     - Parameter x: **REQUIRED** The horizontal line of the matrix to decide the start point, from 0 to 15.
     - Parameter y: **REQUIRED** The vertical line of the matrix to decide the start point, from 0 to 8.
     - Parameter width: **REQUIRED** The number of pixels in the horizontal direction.
     - Parameter height: **REQUIRED** The number of pixels in the vertical direction.
     - Parameter brightness: **REQUIRED** The brightness level of all the pixels. Each byte stands for the brightness of each pixel
     */
    public func writeBitmap(x: Int, y: Int, width: Int, height: Int, data: [UInt8]) {
        guard x < self.width && y < self.height && width >= 1 && height >= 1 else {
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
            rowData[0] = pwmRegOffset + UInt8(cY * self.width + x)
            i2c.write(rowData, to: address)
        }
    }

    
    /// Set all pixels to a specified brightness.
    /// - Parameter brightness: **REQUIRED** The value between 0 and 255 to set the brightness. By default, all pixels are set to 0.
    public func fill(_ brightness: UInt8 = 0x00) {
        var data = [UInt8](repeating: brightness, count: 144 + 1)
        data[0] = pwmRegOffset
        i2c.write(data, to: address)
    }
}

extension IS31FL3731 {

    private enum Register: UInt8 {
        case configuration      = 0x00
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
        case command            = 0xFD
    }

    private func selectPage(_ page: UInt8) {
        guard page < 8 || page == functionPage else { return }
        let data = [Register.command.rawValue, page]
        i2c.write(data, to: address)
    }

    private func writeRegister(_ register: Register, _ value: UInt8) {
        selectPage(functionPage)
        let data = [register.rawValue, value]
        i2c.write(data, to: address)
        selectPage(currentFrame)
    }

    private func readRegister(_ register: Register) -> UInt8 {
        selectPage(functionPage)
        i2c.write(register.rawValue, to: address)
        let ret = i2c.readByte(from: address) 
        selectPage(currentFrame)

        if let ret = ret {
            return ret
        } else {
            print("IS31FL3731 readRegister error!")
            return 0
        }
    }

    private func readData(_ register: UInt8) -> UInt8 {
        writeRegister(.shutdown, 0)
        i2c.write(register, to: address)
        let ret = i2c.readByte(from: address)
        writeRegister(.shutdown, 1)
        if let ret = ret {
            return ret
        } else {
            print("IS31FL3731 readRegister error!")
            return 0
        }
    }

    private func controlRegInit(_ value: Bool) {
        var data: [UInt8]

        if value {
            data = [UInt8](repeating: 0xFF, count: 0x12 + 1)
        } else {
            data = [UInt8](repeating: 0x00, count: 0x12 + 1)
        }

        data[0] = 0x00
        i2c.write(data, to: address)
    }

    private func blinkRegInit(_ value: Bool) {
        var data: [UInt8]

        if value {
            data = [UInt8](repeating: 0xFF, count: 0x12 + 1)
        } else {
            data = [UInt8](repeating: 0x00, count: 0x12 + 1)
        }

        data[0] = 0x12
        i2c.write(data, to: address)
    }
    
    private func startup() {
        writeRegister(.shutdown, 1)
        sleep(ms: 10)
    }

    private func shutdown() {
        writeRegister(.shutdown, 0)
        sleep(ms: 10)
    }

}


#if canImport(MadDisplay)
import protocol MadDisplay.BitmapWritable

extension IS31FL3731: BitmapWritable {

}

#endif
