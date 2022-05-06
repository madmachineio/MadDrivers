// Read all channels of the sensor consecutively. It ensures the data is concurrent.
// The sensor returns the amount of visible lights, clear and NIR (near IR) light.
import SwiftIO
import MadBoard
import AS7341

let i2c = I2C(Id.I2C0)
let sensor = AS7341(i2c)

while true {
    print(sensor.readChannels())
    sleep(ms: 1000)
}


