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
            print("Acceleration: \(sensor.readAcceleration())")
            print("Rotation: \(sensor.readRotation())")
            sleep(ms: 1000)
        }
    }
}
