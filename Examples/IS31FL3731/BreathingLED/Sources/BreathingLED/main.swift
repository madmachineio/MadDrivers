import SwiftIO
import MadBoard
import IS31FL3731

let i2c = I2C(Id.I2C0)
let led = IS31FL3731(i2c: i2c)

// Set the brightness of all LEDs to 50.
led.fill(50)
led.startBreath()
// Display the breathing effect endlessly.
led.setAutoPlay(1)

while true {
    sleep(ms: 1000)
}
