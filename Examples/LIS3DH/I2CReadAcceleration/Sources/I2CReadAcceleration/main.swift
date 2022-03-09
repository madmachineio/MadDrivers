// Read accelerations on the x, y, z-axis every second.
import SwiftIO
import MadBoard
import LIS3DH

let i2c = I2C(Id.I2C0)
let sensor = LIS3DH(i2c)

while true {
    print("x: \(sensor.readX())g")
    print("y: \(sensor.readY())g")
    print("z: \(sensor.readZ())g")
    sleep(ms: 1000) 
}