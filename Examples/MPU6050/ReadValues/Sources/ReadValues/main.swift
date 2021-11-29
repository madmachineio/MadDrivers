import SwiftIO
import MadBoard
import MPU6050

let i2c = I2C(Id.I2C1)
let sensor = MPU6050(i2c)

while true {
    let acceleration = sensor.readAcceleration()
    let rotation = sensor.readRotation()
    
    print("Acceleration: \(acceleration)")
    print("Rotation: \(rotation)")
    sleep(ms: 1000)
}
