// Read accelerations on the x, y, z-axis every second.
import SwiftIO
import MadBoard
import LIS3DH

let i2c = I2C(Id.I2C0)
let sensor = LIS3DH(i2c)

while true {
    print("x: \(getFloatString(sensor.readX()))g")
    print("y: \(getFloatString(sensor.readY()))g")
    print("z: \(getFloatString(sensor.readZ()))g")
    sleep(ms: 1000) 
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}