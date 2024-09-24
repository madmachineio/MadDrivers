// Read and print the red, green, blue, clear color data every second.
import SwiftIO
import MadBoard
import APDS9960

let i2c = I2C(Id.I2C0)
let sensor = APDS9960(i2c)

// Enable the color detection first before reading data.
sensor.enableColor()

while true {
    let rawValue = sensor.readColor()
    print("Rawvalue: red = \(rawValue.red), green = \(rawValue.green), blue = \(rawValue.blue), clear = \(rawValue.clear)")
    sleep(ms: 1000)
}
