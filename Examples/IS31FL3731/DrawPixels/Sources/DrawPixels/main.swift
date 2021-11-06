import SwiftIO
import MadBoard
import IS31FL3731

let i2c = I2C(Id.I2C0)
let led = IS31FL3731(i2c: i2c)

// Draw the first and last row of the matrix.
for x in 0..<16 {
    led.writePixel(x: x, y: 0, brightness: 50)
    led.writePixel(x: x, y: 8, brightness: 50)
}

// Draw the first and last column of the matrix.
for y in 0..<9 {
    led.writePixel(x: 0, y: y, brightness: 50)
    led.writePixel(x: 15, y: y, brightness: 50)
}

while true {
    sleep(ms: 1000)
}

