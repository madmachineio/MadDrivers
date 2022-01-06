// Read and print the red, green, blue, clear color data every second.
import SwiftIO
import MadBoard
import APDS9960

let i2c = I2C(Id.I2C1)
let sensor = APDS9960(i2c)

// Enable the color detection first before reading data.
sensor.enableColor()

while true {
    print(sensor.readColor())
    sleep(ms: 1000)
}
