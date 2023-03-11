// Read pressure and temperature using I2C communication and print the values.

import SwiftIO
import MadBoard
import MS5611

@main
public struct I2CReadPressure {
    public static func main() {
        let i2c = I2C(Id.I2C0)
        let sensor = MS5611(i2c)
        
        while true {
            print(sensor.read())
            sleep(ms: 1000)
        }
    }
}
