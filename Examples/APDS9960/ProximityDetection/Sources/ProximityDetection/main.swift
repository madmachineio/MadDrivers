// Read proximity every second. The value represents the changes of distance
// between the sensor and the object or your hand. The closer the distance,
// the higher the value.
import SwiftIO
import MadBoard
import APDS9960

let i2c = I2C(Id.I2C0)
let sensor = APDS9960(i2c)

// Enable the proximity detection first.
sensor.enableProximity()

while true {
    print(sensor.readProximity())
    sleep(ms: 1000)
}
