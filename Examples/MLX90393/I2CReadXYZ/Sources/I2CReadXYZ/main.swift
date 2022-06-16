// Communicate with the sensor using I2C protocol to measure magnetic field on
// x, y, z-axis and represent the values in microteslas.
import SwiftIO
import MadBoard
import MLX90393

let i2c = I2C(Id.I2C0)
let sensor = MLX90393(i2c)


while true {
    print("Magnetic field: \(sensor.readXYZ())uT")
    sleep(ms: 1000)
}


