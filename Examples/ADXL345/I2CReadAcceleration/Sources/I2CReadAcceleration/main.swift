import SwiftIO
import MadBoard
import ADXL345

let i2c = I2C(Id.I2C1)
let sensor = ADXL345(i2c)

while true {
    sleep(ms: 1000)
    let values = sensor.readXYZ()
    print(values)
}