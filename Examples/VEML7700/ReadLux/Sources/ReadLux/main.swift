// Read ambient light value and print it every second.
import SwiftIO
import MadBoard
import VEML7700

let i2c = I2C(Id.I2C0)
let sensor = VEML7700(i2c)

while true {
    print("Lux: \(sensor.readLux())")
    sleep(ms: 1000)
}
