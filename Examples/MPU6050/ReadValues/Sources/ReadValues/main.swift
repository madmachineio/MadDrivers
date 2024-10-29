// Read accelerations and angular velocity on x, y, z-axis to know the movement.
import SwiftIO
import MadBoard
import MPU6050

let i2c = I2C(Id.I2C0)
let sensor = MPU6050(i2c)


while true {
    let (aX, aY, aZ) = sensor.readAcceleration()
    let (rX, rY, rZ) = sensor.readRotation()

    print("Acceleration: \(getFloatString(aX)), \(getFloatString(aY)), \(getFloatString(aZ))")
    print("Rotation: \(getFloatString(rX)), \(getFloatString(rY)), \(getFloatString(rZ))")
    sleep(ms: 1000)
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}