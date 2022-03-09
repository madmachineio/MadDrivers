// Read distance and print the values per second.
import SwiftIO
import MadBoard
import VL53L0x

let i2c = I2C(Id.I2C0)
let sensor = VL53L0x(i2c)

while true {
    let value = sensor.readRange()
    if let value = value {
        print("distance: \(value)mm")
    } else {
        print("out of range")
    }

    sleep(ms: 1000)
}