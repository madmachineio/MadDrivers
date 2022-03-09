// Read accelerations on x, y, z-axis per second and print them out.
import SwiftIO
import MadBoard
import ADXL345

let i2c = I2C(Id.I2C0)
let accelerometer = ADXL345(i2c)

while true {
    sleep(ms: 1000)
    let values = accelerometer.readXYZ()
    print(values)
}