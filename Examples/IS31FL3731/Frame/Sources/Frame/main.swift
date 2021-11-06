import SwiftIO
import MadBoard
import IS31FL3731
import MadDisplay

let i2c = I2C(Id.I2C0)
let led = IS31FL3731(i2c: i2c)

for f in 0..<8 {
    led.setToFrame(f, show: false)
    led.fill()
    for x in f..<(16 - f) {
        for y in 0..<(9-f) {
            led.writePixel(x: x, y: y, brightness: 50)
        }
    }
}

led.setAutoPlay()

while true {
    sleep(ms: 1000)
}

