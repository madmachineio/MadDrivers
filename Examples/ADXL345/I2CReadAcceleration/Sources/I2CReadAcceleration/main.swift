// Read accelerations on x, y, z-axis per second and print them out.
import SwiftIO
import MadBoard
import ADXL345

let i2c = I2C(Id.I2C0)
let accelerometer = ADXL345(i2c)

while true {
    sleep(ms: 1000)
    let values = accelerometer.readXYZ()
    print("x: \(getFloatString(values.x)), y: \(getFloatString(values.y)), z: \(getFloatString(values.z))")
}


func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}