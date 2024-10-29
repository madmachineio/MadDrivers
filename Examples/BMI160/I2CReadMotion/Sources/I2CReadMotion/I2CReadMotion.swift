// Read the acceleration and rotation values from the sensor using I2C.
import SwiftIO
import MadBoard
import BMI160

@main
public struct I2CReadMotion {
    public static func main() {
        let i2c = I2C(Id.I2C0)
        let sensor = BMI160(i2c)

        while true {
            let (aX, aY, aZ) = sensor.readAcceleration()
            let (rX, rY, rZ) = sensor.readRotation()

            print("Acceleration: \(getFloatString(aX)), \(getFloatString(aY)), \(getFloatString(aZ))")
            print("Rotation: \(getFloatString(rX)), \(getFloatString(rY)), \(getFloatString(rZ))")
            sleep(ms: 1000)
        }
    }
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}