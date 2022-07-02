// Read temperature values of 8x8 pixels from the sensor.

import SwiftIO
import MadBoard
import AMG88xx

let i2c = I2C(Id.I2C0)
let sensor = AMG88xx(i2c)

while true {
    print(sensor.readPixels())
    sleep(ms: 1000)
}
