// Read the 8x8 temperature values and display the image of thermal radiation.

import SwiftIO
import MadBoard
import AMG88xx
import ST7789

let i2c = I2C(Id.I2C0)
let sensor = AMG88xx(i2c)

// The screen size.
let width = 240
let height = 320

// Initalize the pins for the screen.
let spi = SPI(Id.SPI0, speed: 30_000_000)
let cs = DigitalOut(Id.D0)
let dc = DigitalOut(Id.D1)
let rst = DigitalOut(Id.D2)
let bl = DigitalOut(Id.D3)
let screen = ST7789(spi: spi, cs: cs, dc: dc, rst: rst, bl: bl,
                    width: width, height: height)

// Set the temperature boundary used for thermal image.
// Please adjust them according to your current temperature.
let tempResolution: Float = 0.25
let maxRaw: Float = 32 / tempResolution
let minRaw: Float = 26 / tempResolution

// The colors from blue to red used for thermal image.
let colors: [UInt16] = [
    0x480F,
    0x400F,0x400F,0x400F,0x4010,0x3810,0x3810,0x3810,0x3810,0x3010,0x3010,
    0x3010,0x2810,0x2810,0x2810,0x2810,0x2010,0x2010,0x2010,0x1810,0x1810,
    0x1811,0x1811,0x1011,0x1011,0x1011,0x0811,0x0811,0x0811,0x0011,0x0011,
    0x0011,0x0011,0x0011,0x0031,0x0031,0x0051,0x0072,0x0072,0x0092,0x00B2,
    0x00B2,0x00D2,0x00F2,0x00F2,0x0112,0x0132,0x0152,0x0152,0x0172,0x0192,
    0x0192,0x01B2,0x01D2,0x01F3,0x01F3,0x0213,0x0233,0x0253,0x0253,0x0273,
    0x0293,0x02B3,0x02D3,0x02D3,0x02F3,0x0313,0x0333,0x0333,0x0353,0x0373,
    0x0394,0x03B4,0x03D4,0x03D4,0x03F4,0x0414,0x0434,0x0454,0x0474,0x0474,
    0x0494,0x04B4,0x04D4,0x04F4,0x0514,0x0534,0x0534,0x0554,0x0554,0x0574,
    0x0574,0x0573,0x0573,0x0573,0x0572,0x0572,0x0572,0x0571,0x0591,0x0591,
    0x0590,0x0590,0x058F,0x058F,0x058F,0x058E,0x05AE,0x05AE,0x05AD,0x05AD,
    0x05AD,0x05AC,0x05AC,0x05AB,0x05CB,0x05CB,0x05CA,0x05CA,0x05CA,0x05C9,
    0x05C9,0x05C8,0x05E8,0x05E8,0x05E7,0x05E7,0x05E6,0x05E6,0x05E6,0x05E5,
    0x05E5,0x0604,0x0604,0x0604,0x0603,0x0603,0x0602,0x0602,0x0601,0x0621,
    0x0621,0x0620,0x0620,0x0620,0x0620,0x0E20,0x0E20,0x0E40,0x1640,0x1640,
    0x1E40,0x1E40,0x2640,0x2640,0x2E40,0x2E60,0x3660,0x3660,0x3E60,0x3E60,
    0x3E60,0x4660,0x4660,0x4E60,0x4E80,0x5680,0x5680,0x5E80,0x5E80,0x6680,
    0x6680,0x6E80,0x6EA0,0x76A0,0x76A0,0x7EA0,0x7EA0,0x86A0,0x86A0,0x8EA0,
    0x8EC0,0x96C0,0x96C0,0x9EC0,0x9EC0,0xA6C0,0xAEC0,0xAEC0,0xB6E0,0xB6E0,
    0xBEE0,0xBEE0,0xC6E0,0xC6E0,0xCEE0,0xCEE0,0xD6E0,0xD700,0xDF00,0xDEE0,
    0xDEC0,0xDEA0,0xDE80,0xDE80,0xE660,0xE640,0xE620,0xE600,0xE5E0,0xE5C0,
    0xE5A0,0xE580,0xE560,0xE540,0xE520,0xE500,0xE4E0,0xE4C0,0xE4A0,0xE480,
    0xE460,0xEC40,0xEC20,0xEC00,0xEBE0,0xEBC0,0xEBA0,0xEB80,0xEB60,0xEB40,
    0xEB20,0xEB00,0xEAE0,0xEAC0,0xEAA0,0xEA80,0xEA60,0xEA40,0xF220,0xF200,
    0xF1E0,0xF1C0,0xF1A0,0xF180,0xF160,0xF140,0xF100,0xF0E0,0xF0C0,0xF0A0,
    0xF080,0xF060,0xF040,0xF020,0xF800]

// An array to store the colors for the screen. The screen needs UInt16 colors
// (5 bit for red, 6 bits for green and 5 bits for blue).
var data = [UInt8](repeating: 0, count: width * height * 2)

// The count of data that will be added to every two original readings for interpolation.
let interpolationCount = 6
// The width and height of pixels after interpolation.
let newWidth = interpolationCount * (8 - 1) + 8
let newHeight = interpolationCount * (8 - 1) + 8

// An array to store interpolated data.
var newPixels = [[Float]](repeating: [Float](repeating: 0, count: newWidth), count: newHeight)

// Arrarys to store the raw values from the sensor.
var rawPixels = [Int](repeating: 0, count: 8 * 8)
var rawPixels88 = [[Float]](repeating: [Float](repeating: 0, count: 8), count: 8)

while true {
    // Read 64 (8x8) raw values of temperature.
    sensor.readRawPixels(&rawPixels)

    // Turn the readings into arrays of 8 rows and 8 rows for easier reference.
    for row in 0..<8 {
        for column in 0..<8 {
            rawPixels88[row][column] = Float(rawPixels[column + row * 8])
        }
    }

    interpolate(count: interpolationCount, rawData: &rawPixels88, newData: &newPixels)

    // Iterate all interpolated data to get color data for all pixels on the screen.
    for row in 0..<newHeight {
        for column in 0..<newWidth {
            var raw = newPixels[column][row]
            if raw > maxRaw {
                raw = maxRaw
            } else if raw < minRaw {
                raw = minRaw
            }

            // Compare the temperature with the preset boundary to get a color.
            // High temperature is matched to red and low temperature to blue.
            let index = Int((raw - minRaw) * Float(colors.count - 1) / (maxRaw - minRaw))

            // The color data is sent in bytes, so the color is split into 2 UInt8.
            let hsb = UInt8(colors[index] >> 8)
            let lsb = UInt8(colors[index] & 0xFF)

            // Get color data for one interpolated value.
            // After intepolation, the value is still not enough for all pixels
            // of the screen, so the pixels on screen is divided into grids
            // and each one shows the corresponding color.
            let xmin = column * width / newWidth
            let xmax = (column + 1) * width / newWidth
            let ymin = row * height / newHeight
            let ymax = (row + 1) * height / newHeight

            for x in xmin..<xmax {
                for y in ymin..<ymax {
                    let pos = (x + y * width) * 2
                    data[pos] = hsb
                    data[pos+1] = lsb
                }
            }
        }
    }

    // Pass all pixel info to the screen using SPI communication to display the
    // generated thermal image.
    screen.writeScreen(data)
}

// The original pixels from the sensor is 8x8. By comparison, the screen is
// much bigger. If you directly enlarge the original pixels to match the screen,
// the display will be blocky and fuzzy.
// So you will use a interpolation method to estimate more values in between
// known points.
// There are many methods to interpolate the data. You could try other ways
// to get better images.
func interpolate(count: Int, rawData: inout [[Float]], newData: inout [[Float]]) {
    // Two factors for the interpolation. It tells how close the new point is to
    // its adjacent points.
    var ku: Float = 0
    var kv: Float = 0

    // The width and height of pixels after interpolation.
    let width = count * (8 - 1) + 8
    let height = count * (8 - 1) + 8
    let divider = count + 1

    // Calculate new data points based on the original 8x8 data.
    var a = 0

    for y in 0..<height {
        let remainderY = y % divider

        if y > 2 && remainderY == 1 {
            a += 1
        }

        if y != 0 && remainderY == 0 {
            ku = 1
        } else if remainderY == 0 {
            ku = 0
        } else {
            ku = Float(remainderY) * 8 / Float(height)
        }

        var b = 0

        for x in 0..<width {
            let remainderX = x % divider

            if x > 2 && remainderX == 1{
                b += 1
            }

            if x != 0 && remainderX == 0 {
                kv = 1
            } else if remainderX == 0 {
                kv = 0
            } else {
                kv = Float(remainderX) * 8 / Float(width)
            }

            // Calculate the value using the factors and the adjacent points.
            newData[y][x] = (1 - ku) * (1 - kv) * rawData[a][b]
                            + (1 - ku) * kv * rawData[a][b + 1]
                            + ku * (1 - kv) * rawData[a + 1][b]
                            + ku * kv * rawData[a + 1][b + 1]
        }
    }
}

