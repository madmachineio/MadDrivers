// Communicate with the sensor using I2C protocol to measure magnetic field on
// x, y, z-axis and represent the values in microteslas.
import SwiftIO
import MadBoard
import MLX90393

let i2c = I2C(Id.I2C0)
let sensor = MLX90393(i2c)


while true {
    let (mX, mY, mZ) = sensor.readXYZ()

    print("x: \(getFloatString(mX))uT")
    print("y: \(getFloatString(mY))uT")
    print("z: \(getFloatString(mZ))uT")
    sleep(ms: 1000) 
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}
