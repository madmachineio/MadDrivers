import SwiftIO
import MadBoard
import BH1750

let i2c = I2C(Id.I2C1)
let sensor = BH1750(i2c)

while true {
    print("Lux: \(sensor.readLux())")
    sleep(ms: 1000)
}